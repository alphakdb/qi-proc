/ Common library used by websocket feed handlers

.feed.H:0#0i
.feed.pc:{[h] .feed.H:.feed.H except h;.qi.info "tp disconnected - switched to modular mode"}

.feed.upd:{[t;x]
  t insert x;
  if[count .feed.H;
    -25!(.feed.H;(`.u.upd;t;get flip get t));
    delete from t];
  }

.feed.tpreconnect:{
  if[count[.feed.H]<count p:.qi.tosym .proc.self.publish_to;
    .feed.H:{x where not null x}.ipc.conn each p;
    neg[.feed.H]@\:(`.tp.regfeed;.proc.self.pkg)];
  }

.feed.start:{[header;url]
    .qi.info(`.feed.start;header;url);
    if[.qi.isproc;.feed.tpreconnect[];
      if[not count .feed.H;.qi.info"Could not connect to tp - switched to modular mode"]];
    .qi.info"Connection sequence initiated...";
    if[first c:.qi.try[url;header;0Ni];
      :.qi.info"Connection success"];
    .qi.error err:c 2;
    .qi.frompkg[`proc;`profile];
    if[not null p:.profile.gen`;
      .qi.error"Try sourcing the profile before running\n\n";
      -1"------------ SUGGESTED COMMANDS ------------ ";
     / -1" good) ", $[.qi.WIN;". ";"source "],.qi.ospath[p]," && q "," "sv 1_.z.X; 
      -1 $[.qi.WIN;"function qi { . '",.qi.spath[p],"'; q qi.q $args }";"alias qi='source ",.qi.spath[p]," && q qi.q'\nqi "," "sv .z.x],"\n"];
    exit 1;
 }

tcounts:.qi.tcounts
.event.addhandler[`.z.pc;`.feed.pc]
if[.qi.isproc;.cron.add[`.feed.tpreconnect;.z.p+.conf.FEED_RECONNECT;.conf.FEED_RECONNECT]];