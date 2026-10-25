{ pkgs }:

let
  lib = pkgs.lib;

  optionalTop = name:
    lib.optional (builtins.hasAttr name pkgs) (builtins.getAttr name pkgs);

  optionalKde = name:
    lib.optional
      (builtins.hasAttr "kdePackages" pkgs && builtins.hasAttr name pkgs.kdePackages)
      (builtins.getAttr name pkgs.kdePackages);

  optionalQt6 = name:
    lib.optional
      (builtins.hasAttr "qt6" pkgs && builtins.hasAttr name pkgs.qt6)
      (builtins.getAttr name pkgs.qt6);

  pythonRuntime = pkgs.python3.withPackages (ps: [
    ps.click
    ps.evdev
    ps.kde-material-you-colors
    ps.loguru
    ps.material-color-utilities
    ps.materialyoucolor
    ps.numpy
    ps.opencv4
    ps.pillow
    ps.psutil
    ps.pycairo
    ps.pygobject3
    ps.secretstorage
    ps.tqdm
    ps.websockets
    ps.yt-dlp
    ps.ytmusicapi
  ]);

  runtimeDeps =
    with pkgs; [
      bash
      coreutils
      curl
      deno
      findutils
      gawk
      git
      gnugrep
      gnused
      jq
      procps
      pythonRuntime
      ripgrep
      rsync
      systemd
      xdg-user-dirs
      xdg-utils

      quickshell
      wl-clipboard
      cliphist
      grim
      slurp
      playerctl
      libnotify
      glib
      pipewire
      pulseaudio
      wireplumber
      yt-dlp
    ]
    ++ optionalTop "bc"
    ++ optionalTop "brightnessctl"
    ++ optionalTop "cava"
    ++ optionalTop "ddcutil"
    ++ optionalTop "ffmpeg"
    ++ optionalTop "fish"
    ++ optionalTop "foot"
    ++ optionalTop "geoclue2"
    ++ optionalTop "gnome-desktop"
    ++ optionalTop "hyprpicker"
    ++ optionalTop "gum"
    ++ optionalTop "imagemagick"
    ++ optionalTop "kitty"
    ++ optionalTop "libqalculate"
    ++ optionalTop "matugen"
    ++ optionalTop "mpv"
    ++ optionalTop "nautilus"
    ++ optionalTop "networkmanager"
    ++ optionalTop "socat"
    ++ optionalTop "songrec"
    ++ optionalTop "swappy"
    ++ optionalTop "tesseract"
    ++ optionalTop "translate-shell"
    ++ optionalTop "upower"
    ++ optionalTop "wf-recorder"
    ++ optionalTop "wlsunset"
    ++ optionalTop "wtype"
    ++ optionalTop "xwayland-satellite"
    ++ optionalTop "ydotool"
    ++ optionalTop "yt-dlp-ejs"
    ++ optionalKde "breeze-icons"
    ++ optionalKde "kdialog"
    ++ optionalKde "kirigami"
    ++ optionalKde "kconfig"
    ++ optionalKde "plasma-integration"
    ++ optionalKde "syntax-highlighting"
    ++ optionalKde "xembedsniproxy"
    ++ optionalQt6 "qt5compat"
    ++ optionalQt6 "qtbase"
    ++ optionalQt6 "qtdeclarative"
    ++ optionalQt6 "qtimageformats"
    ++ optionalQt6 "qtmultimedia"
    ++ optionalQt6 "qtsvg"
    ++ optionalQt6 "qttools"
    ++ optionalQt6 "qttranslations"
    ++ optionalQt6 "qtwayland";

  materialSymbolsFont =
    if builtins.hasAttr "material-symbols" pkgs
    then pkgs.makeFontsConf { fontDirectories = [ pkgs.material-symbols ]; }
    else null;
  materialSymbolsWrapperArg =
    lib.optionalString (materialSymbolsFont != null)
      "--set FONTCONFIG_FILE \"${materialSymbolsFont}\" \\";

  qmlDeps =
    (lib.optional
      (builtins.hasAttr "kdePackages" pkgs && builtins.hasAttr "kirigami" pkgs.kdePackages)
      pkgs.kdePackages.kirigami.passthru.unwrapped)
    ++ optionalKde "syntax-highlighting"
    ++ optionalQt6 "qt5compat"
    ++ optionalQt6 "qtdeclarative"
    ++ optionalQt6 "qtimageformats"
    ++ optionalQt6 "qtmultimedia"
    ++ optionalQt6 "qtsvg"
    ++ optionalQt6 "qtwayland";

  giDeps = (optionalTop "gnome-desktop") ++ [ pkgs.glib ];
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "inir";
  version = lib.removeSuffix "\n" (builtins.readFile ../VERSION);
  src = lib.cleanSourceWith {
    src = ../.;
    filter = import ./runtime-source-filter.nix { inherit lib; root = ../.; };
  };

  nativeBuildInputs = [ pkgs.makeWrapper pkgs.rsync pkgs.go pythonRuntime ];

  installPhase = ''
    runHook preInstall

    runtime="$out/share/quickshell/inir"
    mkdir -p "$runtime" "$out/bin"

    python3 sdata/lib/runtime-payload.py copy --root . --target "$runtime"

    export GOCACHE="$TMPDIR/go-cache"
    mkdir -p "$runtime/scripts/colors/bin"
    go build -trimpath -o "$runtime/scripts/colors/bin/inir-vscode-themegen" ./scripts/colors/vscode_themegen
    go build -trimpath -o "$runtime/scripts/colors/bin/inir-opencode-themegen" ./scripts/colors/opencode_themegen
    go build -trimpath -o "$runtime/scripts/colors/bin/inir-zed-themegen" ./scripts/colors/zed_themegen
    go build -trimpath -o "$runtime/scripts/colors/bin/inir-washi" ./scripts/colors/washi

    find "$runtime/scripts" -type f -name '*.py' -exec sed -i -E '1s|^#!.*/bin/.*python.*|#!/usr/bin/env python3|' {} +
    find "$runtime/scripts" -type f -name '*.sh' -exec sed -i -E '1s|^#!.*/bin/.*bash.*|#!/usr/bin/env bash|' {} +
    find "$runtime/scripts" -type f -name '*.fish' -exec sed -i -E '1s|^#!.*/bin/.*fish.*|#!/usr/bin/env fish|' {} +

    find "$runtime/modules" "$runtime/services" "$runtime/defaults" "$runtime/scripts" \
      -type f \( -name '*.qml' -o -name '*.js' -o -name '*.sh' -o -name '*.py' \) \
      -exec sed -i '1!s#/usr/bin/##g' {} +

    chmod +x "$runtime/setup" "$runtime/scripts/inir"
    find "$runtime/scripts" -type f \( -name '*.sh' -o -name '*.fish' -o -name '*.py' \) -exec chmod +x {} +
    patchShebangs "$runtime/scripts"

    makeWrapper "$runtime/scripts/inir" "$out/bin/inir" \
      --prefix PATH : "${lib.makeBinPath runtimeDeps}" \
      --prefix QML2_IMPORT_PATH : "${lib.makeSearchPath "lib/qt-6/qml" qmlDeps}" \
      --prefix QT_PLUGIN_PATH : "${lib.makeSearchPath "lib/qt-6/plugins" qmlDeps}" \
      --prefix GI_TYPELIB_PATH : "${lib.makeSearchPath "lib/girepository-1.0" giDeps}" \
      ${materialSymbolsWrapperArg}
      --set-default INIR_VENV "${pythonRuntime}" \
      --set-default ILLOGICAL_IMPULSE_VIRTUAL_ENV "${pythonRuntime}" \
      --set-default INIR_SYSTEM_RUNTIME_DIR "$runtime" \
      --set-default INIR_FALLBACK_SYSTEM_RUNTIME_DIR "$runtime"

    runHook postInstall
  '';

  passthru = {
    inherit runtimeDeps pythonRuntime qmlDeps;
    runtimeDependencies = runtimeDeps;
    qmlImportPath = lib.makeSearchPath "lib/qt-6/qml" qmlDeps;
    qtPluginPath = lib.makeSearchPath "lib/qt-6/plugins" qmlDeps;
  };

  meta = {
    description = "Complete desktop shell for Niri, built on Quickshell";
    homepage = "https://github.com/snowarch/inir";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "inir";
  };
}
