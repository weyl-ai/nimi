{
  runCommandLocal,
  writeShellApplication,
  nimi,
  lib,
}:
let
  N = 5;
  testString = "goodbye world";

  failingService = writeShellApplication {
    name = "failing-service";
    text = ''
      echo "${testString}"
      exit 1
    '';
  };

  nimiWrapper = nimi.mkNimiBin {
    services."failing-service" = {
      process.argv = [
        (lib.getExe failingService)
      ];
    };
    settings.restart.mode = "up-to-count";
    settings.restart.count = N;
  };
in
runCommandLocal "restart-runs-n-times" { } ''
  set -euo pipefail

  ${lib.getExe nimiWrapper} &> nimi_logs.txt
  occurred="$(grep -c "goodbye world" nimi_logs.txt)"

  if [ "$occurred" != "${toString (N + 1)}" ]; then
    echo "Failed to find '${testString}' ${toString (N + 1)} time(s), got $occurred"
    echo "nimi logs: $(cat nimi_logs.txt)"
    exit 1
  fi

  echo "Successfully found '${testString}' ${toString (N + 1)} times"
  echo "${lib.getExe nimiWrapper} &> nimi_logs.txt"
  cat nimi_logs.txt
  mkdir "$out"
''
