.profile.makeenv:{$[.qi.WIN;"$env:",.qi.tostr[x]," = \"",.qi.tostr[y],"\"";.qi.tostr[x],"=",.qi.tostr y]}
.profile.appendenv:{$[.qi.WIN;"$env:",.qi.tostr[x]," += \";",y,"\"";.qi.tostr[x],"=",y]}

.profile.gen:{
  /if[.qi.exists p:.qi.path(.conf.QI_HOME;`profiles;.z.o;$[.qi.MAC;system"uname -m";()];`qi.profile);:p];
  if[.qi.exists p:.qi.path(.conf.QI_HOME;`qi.profile);:p];
  .qi.info".profile.gen";
  ex:$[w:.qi.WIN;"";"export "];
  pr:enlist"#",ex,.profile.makeenv[`GITHUB_TOKEN;""];
  pr,:enlist ex,.profile.makeenv[`SSL_VERIFY_SERVER;"NO"];
  /if[not first ssl:.qi.try[-26!;::;{x}];
  if[.qi.WIN;
    .qi.importx[`fetch;dw:`$"deps-win"];
    pr,:enlist .profile.appendenv[`PATH;.qi.ospath .qi.pkgs dw]];
  if[.qi.MAC;
    .qi.importx[`fetch;dm:`$"deps-mac"];
    {system"codesign -f -s - ",.qi.spath x}each .qi.paths[lpath:.qi.ospath(.qi.pkgs dm;system"uname -m");"lib*"];
    pr,:enlist ex,.profile.appendenv[`DYLD_LIBRARY_PATH;lpath]];
  if[count pr;
    p 0: pr;
    .qi.info"profile written to: ",.qi.spath p;
    :p];
  `
  }