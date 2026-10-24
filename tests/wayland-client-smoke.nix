{ pkgs }:

# Headless client integration smoke test. This deliberately does not provide an
# X server or XWayland: clients must connect to a real Wayland socket.
pkgs.runCommand "neodots-wayland-client-smoke"
  {
    nativeBuildInputs = with pkgs; [
      coreutils
      dbus
      electron
      gcc
      pkg-config
      weston
    ];

    buildInputs = with pkgs; [
      gtk4
      qt6.qtbase
      qt6.qtwayland
      SDL2
    ];
  }
  ''
    set -euo pipefail

    work="$TMPDIR/neodots-wayland-smoke"
    mkdir -p "$work"

    cat > "$work/gtk-smoke.c" <<'EOF'
    #include <gtk/gtk.h>

    static gboolean finish(gpointer data) {
      g_main_loop_quit((GMainLoop *)data);
      return G_SOURCE_REMOVE;
    }

    int main(void) {
      gtk_init();

      GtkWidget *window = gtk_window_new();
      GtkWidget *label = gtk_label_new("GTK Wayland smoke test");
      gtk_window_set_child(GTK_WINDOW(window), label);
      gtk_window_present(GTK_WINDOW(window));

      GMainLoop *loop = g_main_loop_new(NULL, FALSE);
      g_timeout_add(750, finish, loop);
      g_main_loop_run(loop);

      gtk_window_destroy(GTK_WINDOW(window));
      g_main_loop_unref(loop);
      return 0;
    }
    EOF

    cat > "$work/qt-smoke.cpp" <<'EOF'
    #include <QApplication>
    #include <QLabel>
    #include <QTimer>

    int main(int argc, char **argv) {
      QApplication app(argc, argv);
      QLabel window("Qt Wayland smoke test");
      window.resize(320, 80);
      window.show();
      QTimer::singleShot(750, [&app] { app.quit(); });
      return app.exec();
    }
    EOF

    cat > "$work/sdl-smoke.c" <<'EOF'
    #include <SDL.h>

    int main(void) {
      if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        SDL_Log("SDL_Init failed: %s", SDL_GetError());
        return 1;
      }

      SDL_Window *window = SDL_CreateWindow(
        "SDL Wayland smoke test",
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        320,
        80,
        SDL_WINDOW_SHOWN
      );

      if (window == NULL) {
        SDL_Log("SDL_CreateWindow failed: %s", SDL_GetError());
        SDL_Quit();
        return 2;
      }

      SDL_Delay(750);
      SDL_DestroyWindow(window);
      SDL_Quit();
      return 0;
    }
    EOF

    gcc "$work/gtk-smoke.c" -o "$work/gtk-smoke" \
      $(pkg-config --cflags --libs gtk4)
    g++ -std=c++17 "$work/qt-smoke.cpp" -o "$work/qt-smoke" \
      $(pkg-config --cflags --libs Qt6Widgets)
    gcc "$work/sdl-smoke.c" -o "$work/sdl-smoke" \
      $(pkg-config --cflags --libs sdl2)

    mkdir -p "$work/electron-app"
    cat > "$work/electron-app/package.json" <<'EOF'
    {
      "name": "neodots-electron-wayland-smoke",
      "version": "1.0.0",
      "private": true,
      "main": "main.cjs"
    }
    EOF

    cat > "$work/electron-app/main.cjs" <<'EOF'
    const { app, BrowserWindow } = require("electron");

    app.whenReady().then(() => {
      const window = new BrowserWindow({
        width: 320,
        height: 160,
        show: true,
      });
      window.loadURL("data:text/html,<title>Electron Wayland smoke test</title><h1>Wayland OK</h1>");
      setTimeout(() => app.quit(), 1200);
    });

    app.on("window-all-closed", () => app.quit());
    EOF

    export WORKDIR="$work"
    export XDG_RUNTIME_DIR="$work/runtime"
    export WAYLAND_DISPLAY="wayland-ci"
    export GDK_BACKEND="wayland"
    export QT_QPA_PLATFORM="wayland"
    export SDL_VIDEODRIVER="wayland"
    export NIXOS_OZONE_WL="1"
    export GSK_RENDERER="cairo"
    export QT_PLUGIN_PATH="${pkgs.qt6.qtbase}/lib/qt-6/plugins:${pkgs.qt6.qtwayland}/lib/qt-6/plugins"
    export QT_QPA_PLATFORM_PLUGIN_PATH="${pkgs.qt6.qtwayland}/lib/qt-6/plugins/platforms"
    unset DISPLAY XAUTHORITY

    mkdir -m 0700 -p "$XDG_RUNTIME_DIR"

    weston \
      --backend=headless \
      --renderer=pixman \
      --socket="$WAYLAND_DISPLAY" \
      --idle-time=0 \
      --log="$work/weston.log" &
    weston_pid=$!

    cleanup() {
      kill "$weston_pid" 2>/dev/null || true
      wait "$weston_pid" 2>/dev/null || true
    }
    trap cleanup EXIT

    for _ in $(seq 1 100); do
      if [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
        break
      fi
      if ! kill -0 "$weston_pid" 2>/dev/null; then
        cat "$work/weston.log" >&2 || true
        exit 1
      fi
      sleep 0.1
    done

    if [ ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
      cat "$work/weston.log" >&2 || true
      echo "Weston did not create its Wayland socket" >&2
      exit 1
    fi

    dbus-run-session -- bash -euo pipefail -c '
      run_client() {
        name="$1"
        shift
        echo "Running $name against WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
        timeout 20s "$@" > "$WORKDIR/$name.log" 2>&1 || {
          status=$?
          cat "$WORKDIR/$name.log" >&2 || true
          echo "$name exited with status $status" >&2
          return "$status"
        }
      }

      run_client gtk env WAYLAND_DEBUG=1 "$WORKDIR/gtk-smoke"
      grep -q "wl_display.*get_registry" "$WORKDIR/gtk.log"

      run_client qt env WAYLAND_DEBUG=1 "$WORKDIR/qt-smoke"
      grep -q "wl_display.*get_registry" "$WORKDIR/qt.log"

      run_client sdl env WAYLAND_DEBUG=1 "$WORKDIR/sdl-smoke"
      grep -q "wl_display.*get_registry" "$WORKDIR/sdl.log"

      run_client electron electron \
        --no-sandbox \
        --disable-gpu \
        --disable-dev-shm-usage \
        --enable-features=UseOzonePlatform \
        --ozone-platform=wayland \
        "$WORKDIR/electron-app"
    '

    mkdir -p "$out"
    cat > "$out/results.txt" <<'EOF'
    PASS: headless Weston created a Wayland socket with no X server.
    PASS: GTK4 client created a window over Wayland.
    PASS: Qt6 client created a window over Wayland.
    PASS: SDL2 client created a window over Wayland.
    PASS: Electron client created a window using its Wayland Ozone backend.
    Note: this does not exercise a physical GPU, GDM, user login, portals,
    screen sharing, input-method composition, or Spotify authentication.
    EOF
  ''
