XYBusControlledSynth {
  var
  server,
  target,
  addAction = \addToTail,
  run = true,
  synthDefName,
  defaultSettings,
  synthArgDictionary,
  busDictionary,
  nodeMap,
  fastPlay = false,

  synthObj
  ;

  *new {
    ^super.new.init();
  }

  init {|defName|
    synthDefName = defName;

    server = Server.default;
    target = server;
  }

  makeBusDictionary {
    NotYetImplementedError.throw()
  }

  makeNodeMap {
    if (this.nodeMap.isNil) { this.nodeMap=ProxyNodeMap.new };
    if (this.busDictionary.isNil) { this.makeBusDictionary };

    this.busDictionary.keysValuesDo({|key, value|
      this.nodeMap.map(key, value);
    });

    ^this.nodeMap;
  }

  makeSynthArgs {|synthArgs, target, addAction, run|
    var synthArgArr;
    synthArgArr = Array.new;

    if((target.isNil), { target = this.target }, { this.target = target });
    if((target.isNil), { target = this.target }, { this.target = target });
    if((addAction.isNil), { addAction=this.addAction }, { this.addAction=addAction });
    if((run.isNil), { run=this.run }, { this.run=run });
    if((this.synthArgDictionary.isNil), { this.synthArgDictionary=Dictionary.new });

    forBy(0, synthArgs.size - 2, 2, {|i|
      if((this.busDictionary.includesKey(synthArgs[i])), {
        this.server.sendMsg(\c_set,
          this.busDictionary.at(synthArgs[i]),
          synthArgs[i + 1]
        );
      }, {
        this.synthArgDictionary.put(synthArgs[i], synthArgs[i + 1]);
      });
    });

    if(this.synthArgDictionary.notNil) {
      this.synthArgDictionary.keysValuesDo {|key, value|
        synthArgArr=synthArgArr.add(key);
        synthArgArr=synthArgArr.add(value);
      };
    };

    ^[synthArgArr, target, addAction, run];
  }

  playSynth {|synthArgs, target, addAction, run|
    var synthArgArr;

    if(this.synthObj.isNil) {
      if (this.nodeMap.isNil) {
        this.makeNodeMap

      };

      if(run.isNil) {
        run=this.run
      };

      if((this.fastPlay), {
        synthArgArr = synthArgs;
      }, {
        #synthArgArr, target, addAction, run = this.makeSynthArgs(
          synthArgs, target, addAction, run
        );
      });

      this.synthObj = Synth(this.synthDefName,
        synthArgArr,
        target.asTarget,
        addAction
      ).run(run);

      this.nodeMap.sendToNode(this.synthObj);
    };

    ^this.synthObj;
  }

  playSynthMsg {|synthArgs, target, addAction, run|
    var synthArgArr, msg, mapArr;

    // FIXME(sbl): determine state without nil check
    if(this.synthObj.isNil) {
      msg = Array.new;
      if((this.nodeMap.isNil), { this.makeNodeMap });
      if((run.isNil), { run=this.run });

      if((this.fastPlay), {
        synthArgArr=synthArgs;
      }, {
        #synthArgArr, target, addAction, run=this.makeSynthArgs(
          synthArgs, target, addAction, run
        );
      });

      this.synthObj = Synth.basicNew(this.synthDefName, this.server);
      msg = msg.add(this.synthObj.newMsg(
        target.asTarget,
        synthArgArr,
        addAction
      ));

      msg = msg.add(this.synthObj.runMsg(run));

      mapArr = Array.new;
      this.nodeMap.keysValuesDo {|k, v|
        mapArr = mapArr.add(k);
        mapArr = mapArr.add(v.value);
      };
      msg=msg.add([14, this.synthObj.nodeID] ++ mapArr);
    };

    msg;
  }

  runSynth {|run|
    if((this.synthObj.notNil), { this.synthObj.run(run) });
    this.run=run;
  }

  stopSynth {
    if(this.synthObj.notNil) {
      this.synthObj.free;
      this.synthObj=nil;
    };
  }

  setArgs {|...args|
    args = args.asArray;

    if((this.busDictionary.notNil), {
      if(this.synthArgDictionary.isNil) { this.synthArgDictionary = Dictionary.new; };

      forBy(0, args.size - 2, 2, {|count|
        if((this.busDictionary.includesKey(args[count])), {
          this.server.sendMsg(\c_set,
            this.busDictionary.at(args[count]),
            args[count + 1]
          );
        }, {
          this.synthObj.set(args[count], args[count + 1]);
          this.synthArgDictionary.put(args[count], args[count + 1]);
        })
      })
    }, {
      'Busses not initialized.'.postln;
    });

    ^this.synthObj;
  }

  setArgArray {|...args|
    args = args.asArray;
    if((this.busDictionary.notNil), {
      (this.synthArgDictionary.isNil).if({
        this.synthArgDictionary=Dictionary.new;
      });

      forBy(0, args.size - 2, 2, {|count|
        (this.busDictionary.includesKey(args[count])).if({
          this.server.sendMsg(\c_setn,
            this.busDictionary.at(args[count]),
            args[count + 1].size,
            args[count + 1]
          );
        }, {
          this.synthObj.setn(args[count], args[count + 1]);
        })
      })
    }, {
      'Busses not initialized.'.postln;
    });
    ^this.synthObj;
  }

  getValues {|func|
    this.busarr.getn(this.busDictionary.size, {|busses|
      func.value([busses, this.synthArgDictionary]);
    }
    );
  }

  map {|...args|
    forBy(0, args.size-2, 2, {|i|
      this.nodeMap.map(args[i], args[i + 1]);
    });
    if(this.synthObj.notNil) {
      this.nodeMap.sendToNode(this.synthObj);
    };
    this.nodeMap;
  }
}