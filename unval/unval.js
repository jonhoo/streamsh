#!/usr/bin/sudo /usr/bin/node

try {
  process.setgid('nobody');
  process.setuid('nobody');
} catch (err) {
  console.error("Failed to drop privileges (see source); exiting.");
  return;
}

process.stdin.resume();
process.stdin.setEncoding('utf8');

var d = "";
var out = [];
process.stdin.on('data', function(chunk) {
  d+=chunk;
  if (d.indexOf("\n") > -1) {
    var tmp = d.split("\n");
    d = tmp.pop();
    out = out.concat(decode(tmp));
  }
});

process.stdin.on('end', function() {
  out = out.concat(decode(d.split("\n")));
  out.forEach(function(e){
    process.stdout.write(e);
  });
});

function decode(lines) {
  var o = [];
  var evld = false;
  for (var i in lines){
    var s = lines[i];
    if (s.indexOf(';eval(function(w,i,s,e)') === -1 &&
        s.indexOf('eval(function(p,a,c,k,e,d)') === -1) {
      o.push(s);
      continue;
    }

    var ebits = s.split(";;");
    for (var bit in ebits) {
      var l = ebits[bit];
      l = l.replace("}(", "})(");
      l = l.replace("eval(", "((");
      var v = eval(l);
      o.push(v);
      evld = true;
    }
  }

  if (evld) {
    return decode(o);
  }
  return o;
}
