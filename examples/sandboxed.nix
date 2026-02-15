{
  nimi,
  lib,
  redis,
}:
nimi.mkBwrap {
  services."redis" = {
    process.argv = [ "${lib.getExe' redis "redis-server"}" ];
  };
}
