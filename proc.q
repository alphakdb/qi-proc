/ Process library
/ Communicate with hub

.qi.import`ipc
.qi.import`cron
.qi.frompkg[`proc;`profile]

\d .proc

stacks,:1#.q
self:``name`stackname`fullname!(::;`;`;`);

quit:{[sender] .qi.info".proc.quit called by ",.qi.tostr[sender],". Exiting";exit 0}

ipc.upd:{
  c:(`fullname xkey select from .ipc.conns where name=`hub)upsert select fullname,name,proc:pkg,stackname,port from getstacks`;
  c:`index xasc update index:(`hub;.proc.self.stackname)?stackname from c;
  .ipc.conns:`name xkey delete index from(update name:fullname from c where index=2);
  }

datapath:{[st;typ] .qi.path(.conf.DATA;st;typ)}

init:{[x]
  st:last n:fromfullname x;
  self::``name`stackname`fullname!(::;nm;st;` sv(nm:n 0),st);
  ipc.upd[];
  if[(::)~d:stacks st; '"There are no valid stacks of the name ",string st];
  if[not count me:select from(sp:d`processes)where name=nm;
    show sp;
    '"Could not find a ",string[nm]," process in the ",string[st]," stack"];
  self,:first 0!me;
  self.mystack:sp;
  if[not count sch:{$[count x;`$lower","vs x;x]}.qi.getopt`schemas;
    if[not[count self.subscribe_to]& not self.pkg in`gw`hdb;
      sch:(exec pkg from sp)inter exec k from .qi.packages where kind like"feed"]];
  .qi.importx[`schemas]each sch;
  if[not system"p";system"p ",.qi.tostr self`port];
  .cron.add[`.proc.reporthealth;0Np;.conf.REPORT_HEALTH_PERIOD];
  .event.addhandler[`.z.exit;`.proc.exit]
  .cron.start`;
 }

load1stack:{[p]
  sp:(a:.qi.readj p)`processes;
  pk:`$get[sp][;`pkg];
  if[count err:pk except `hdb,exec k from .qi.packages;show .qi.packages;'"Invalid package(s): ",","sv string err];
  d:`hostname`base_port!("S";7h);
  cfg:{(k#x)$(k:key[x]inter key y)#y}[d;a];
  if[not`hostname in key cfg;cfg:cfg,enlist[`hostname]!enlist`localhost];
  def:`pkg`cmd`hostname`port_offset`taskset`args`subscribe_to`publish_to`port!(`;"";`;0N;"";();()!();();0N);
  pkgs:([]name:key sp)!(key[def]#/:def,/:get sp),'([]options:_[key def]each get sp);
  r:update`$pkg,7h$port_offset,`$publish_to,`$subscribe_to,7h$port from pkgs;
  r:update hostname:cfg`hostname,port:port_offset+cfg`base_port from r where null port,not null port_offset;
  sv[`;`.proc.stacks,st:first` vs last` vs p]set cfg,enlist[`processes]!enlist r;
  sv[`;`.proc.stackpaths,st]set p;
  }

loadstacks:{[st]
  if[not count p:.qi.paths[.conf.STACKS;"*.json"];
    p,:{.qi.cp[x;(.conf.STACKS;`examples),last ` vs x]}each .qi.paths[.qi.pkgs[`proc],`example_stacks;"*.json"]];
  d:p group last each ` vs'p;
  if[not[st~`]&11=abs type st;d:(` sv'((),st),'`json)#d];
  if[0<count empty:where 0=count each d;'"No stack files found for "," "sv string empty];
  if[count dupes:where 1<count each d;
    -1 "\n",.Q.s dupes#d;
    '"Duplicate stack names not allowed"];
  .proc.stacks:1#.q;
  load1stack each get[d][;0];
  if[count err1:sl where max w:(sl:1_key stacks)like/:string[pl:exec k from .qi.packages],'"*";
    '"Cannot have a stack name that is similar to a package name: stacks=",(-3!err1)," packages=",-3!pl where max flip w];
  if[count dupes:select from getstacks[]where 1<(count;i)fby([]stackname;hostname;port);
    show `port xasc dupes;
    '"Duplicate processes found on the same stackname/host/port"];
  ipc.upd[];
  }

getstacks:{raze{[st] `stackname`name`fullname xcols update stackname:st,fullname:` sv'(name,'st)from 0!stacks[st]`processes}each $[null x;1_key stacks;(),x]}

subscribe:{[x]
  if[any(sd:x)~/:(`;::);
    if[not nosubs:(::)~sd:self`subscribe_to;
      nosubs:0=count sd];
    if[nosubs;'".proc.subscribe requires a subscribe_to entry in the process config, or a subscription argument"]];
  if[count w:where null h:.ipc.conn each k:key sd;
    '"Could not connect to ",","sv string k w];
  {x(`.u.wsub;y)}'[h;sd]
  }

initsnapshot:{$[99=type x;[todo_else_remove;.z.s each get x];x[;0]upsert'x[;1]]}

replay:{[logfile]
  if[count logfile;
    if[logfile 0;
      .qi.info"Replaying ",.Q.s1 logfile;
      -11!logfile]];
  }

subinitreplay:{{initsnapshot x`snapshot;replay x`logfile;}each subscribe x;}

getlog:{[x] n:fromfullname x; .qi.path(.conf.DATA;n 1;`logs;` sv n[0],`log)}

if[0=count .qi.getconf[`QI_CMD;""];
  .conf.QI_CMD:1_{$[.qi.MAC;"";.qi.WIN;" start /affinity ",string 0b sv -64#(0b vs 0j),(x#1b),y#0b;" taskset -c ","-"sv string(0;x-1)+y]}[.conf.CORES;.conf.FIRST_CORE]," ",.conf.QBIN," ",.qi.ospath .qi.local`qi.q];

{
  os.startproc:$[.qi.WIN;
    {[profile;args;logpath] (.qi.info;system)@\:"powershell -NoProfile -WindowStyle Hidden -Command \"Invoke-Expression (Get-Content '",profile,"' -Raw); Start-Process -NoNewWindow cmd -ArgumentList '/c ",ssr[.conf.QI_CMD;"start ";"start /B "]," ",args," < NUL >> ",.qi.ospath[logpath]," 2>&1'\""};
    {[profile;args;logpath] 
    sh:"nohup /bin/",$[.qi.MAC;"zsh";"bash"]," -c \"";
    pr:$[count pr:profile;"source ",pr," && ";""];
    (.qi.info;system)@\:sh,pr,.conf.QI_CMD," ",args,"\" < /dev/null >> ",logpath,"  2>&1 &";}];

  os.kill:$[.qi.WIN;{[pid]system"taskkill /",.qi.tostr[pid]," /F"};{[pid] system"kill -9 ",.qi.tostr pid}];

  os.tail:$[.qi.WIN;
    {[logfile;n]system"cmd /C powershell -Command Get-Content ",.qi.ospath[logfile]," -Tail ",.qi.tostr n};
    {[logfile;n]system"tail -n ",.qi.tostr[n]," ",.qi.spath logfile}];
  }[]

isstack:{x in 1_key stacks}
fromfullname:{(v 0;.conf.DEFAULT_STACK^last 1_v:` vs x)}  / e.g. `tp1.dev1 -> `tp1`dev1
tofullnamex:{$[x like"*.*";x;` sv x,y]}  / e.g. `tp1 -> `tp1.dev1 (or `tp1.dev1 -> `tp1.dev1)
tofullname:tofullnamex[;.conf.DEFAULT_STACK]
stackprocs:{[st] exec name from .ipc.conns where stackname=st}
healthpath:{[pname;sname;pid] .qi.local(`.qi;`health;sname;first` vs pname),pid}

reporthealth:{
  healthpath[nm:self.name;st:self.stackname;`latest]set pd:.z.i;
  healthpath[nm;self.stackname;pd]set d:select lastheartbeat:.z.p,used,heap from .Q.w`;
  }

gethealth:{[pname;sname] 
  d:`pid`lastheartbeat`used`heap`path!(0Ni;0Np;0N;0N;`);
  if[not .qi.exists p:healthpath[pn:first` vs pname;sname;`latest];:d];
  if[not .qi.exists hp:healthpath[pn;sname;pid:get p];:d];
  (d,`pid`path!(pid;hp)),get hp
  }

showstatus:{[x]
  r:select name,stackname,fullname,hostname,port from getstacks`;
  if[not null x;r:$["."in s:.qi.tostr x;select from r where fullname=x;"*"in s;select from r where (stackname like s)|(name like s)|fullname like s;select from r where(stackname=x)|name=x]];
  $[0=count r;.qi.info .qi.tostr[x]," does not match any processes / stacks";
  show update status:`down`up .proc.isup'[name;stackname]from r];
  }

getpid:{[pname;sname] gethealth[pname;sname]`pid}

checkhealth:{[pname;sname] ($[null d`pid;0b;os.isup d`pid;1b;[hdel d`path;0b]];`path _d:gethealth[pname;sname])} 

isup:{[pname;sname] first checkhealth[pname;sname]}

up:{[x]
  if[isstack x;:.z.s each stackprocs x];
  profile:.profile.gen`;
  .qi.os.ensuredir first` vs lp:getlog x;
  os.startproc[.qi.spath profile;.qi.tostr x;.qi.spath lp];
  lp
  }

down:{
    if[isstack x;.z.s each stackprocs x;:(::)];
    nm:$[self.stackname=last n:fromfullname x;n 0;` sv n];
    if[not null h:.ipc.conn nm;
      neg[h](`.proc.quit;self.name);
      neg[h][];
      if[mc:0^.conf.MAX_CONNS;if[mc<=count .z.W;if[not .qi.WIN;system"sleep 0.3";hclose h;.z.pc h]]]];
  }

kill:{
  if[(t:type x)within -7 -5h;:os.kill x];
  if[t within 5 7h;:.os.kill each x];
  n:fromfullname x;
  if[x~st:n 1;:.z.s each exec name from .ipc.conns where stackname=st];
  $[null pid:getpid[n 0;st];.qi.error"Could not get pid for ",string x;os.kill pid];
  }

os.isup:$[.qi.WIN;
        {[pid] 0<count @[system;"tasklist /FI \"PID eq ",p,"\" | find \"",(p:.qi.tostr pid),"\"";""]};
        {[pid] 0<count @[system;"ps -p ",.qi.tostr pid;""]}];

tailx:{[pname;n] $[.qi.exists l:getlog pname;os.tail[l;n];'"Log file not found: ",.qi.tostr l]}
tail:{[pname] tailx[pname;.conf.TAIL_ROWS]}

.proc.exit:{if[not null self.name;@[hdel;;`]each .qi.paths[healthpath[self.name;self.stackname;()];(),"*"]]}

loadstacks`