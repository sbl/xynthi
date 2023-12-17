(
~busControlledSynth = (
	reproduce: {|self, clearBusses=false|
		var newSelf;

		newSelf = self.copy;
		newSelf.synthObj = nil;
		newSelf.synthArgDictionary = self.synthArgDictionary.copy;

    if((clearBusses), {
			newSelf.busDictionary=nil;
			newSelf.nodeMap=nil;
		});
		newSelf;
	},
	server: s,
	target: s,
	addAction: \addToTail,
	run: true,
	synthDefName: nil,
	defaultSettings: nil,
	synthArgDictionary: nil,
	busDictionary: nil,
	makeBusDictionary: nil,
	makeNodeMap: {|self|
    // NOTE(sbl): was NodeMap - interface seems to have changed - no map method
		if (self.nodeMap.isNil) { self.nodeMap=ProxyNodeMap.new };
		if (self.busDictionary.isNil) { self.makeBusDictionary };

		self.busDictionary.keysValuesDo({|key, value|
			self.nodeMap.map(key, value);
		});
		self.nodeMap;
	},
	fastPlay: false,

  makeSynthArgs: {|self, synthArgs, target, addAction, run|
		var synthArgArr;
		synthArgArr=Array.new;

		if((target.isNil), { target=self.target }, { self.target=target });
		if((addAction.isNil), { addAction=self.addAction }, { self.addAction=addAction });
    if((run.isNil), { run=self.run }, { self.run=run });
		if((self.synthArgDictionary.isNil), { self.synthArgDictionary=Dictionary.new });

		forBy(0, synthArgs.size - 2, 2, {|i|
			if((self.busDictionary.includesKey(synthArgs[i])), {
				self.server.sendMsg(\c_set,
					self.busDictionary.at(synthArgs[i]),
					synthArgs[i + 1]
				);
			}, {
				self.synthArgDictionary.put(synthArgs[i], synthArgs[i + 1]);
			});
		});

		if(self.synthArgDictionary.notNil) {
			self.synthArgDictionary.keysValuesDo {|key, value|
				synthArgArr=synthArgArr.add(key);
				synthArgArr=synthArgArr.add(value);
			};
		};

		[synthArgArr, target, addAction, run];
	},

	playSynth: {|self, synthArgs, target, addAction, run|
		var synthArgArr;

    if(self.synthObj.isNil) {
			if((self.nodeMap.isNil), { self.makeNodeMap });
			if((run.isNil), { run=self.run });

      if((self.fastPlay), {
				synthArgArr = synthArgs;
			}, {
				#synthArgArr, target, addAction, run=self.makeSynthArgs(
					synthArgs, target, addAction, run
				);
			});

      self.synthObj = Synth(self.synthDefName,
				synthArgArr,
				target.asTarget,
				addAction
			).run(run);

			self.nodeMap.sendToNode(self.synthObj);
		};

		self.synthObj;
	},

	playSynthMsg: {|self, synthArgs, target, addAction, run|
		var synthArgArr, msg, mapArr;

		if(self.synthObj.isNil) {
			msg = Array.new;
			if((self.nodeMap.isNil), { self.makeNodeMap });
			if((run.isNil), { run=self.run });

      if((self.fastPlay), {
				synthArgArr=synthArgs;
			}, {
				#synthArgArr, target, addAction, run=self.makeSynthArgs(
					synthArgs, target, addAction, run
				);
			});

			self.synthObj = Synth.basicNew(self.synthDefName, self.server);
			msg = msg.add(self.synthObj.newMsg(
				target.asTarget,
				synthArgArr,
				addAction
			));

			msg = msg.add(self.synthObj.runMsg(run));

      mapArr = Array.new;
      self.nodeMap.keysValuesDo {|k, v|
        mapArr=mapArr.add(k);
        mapArr=mapArr.add(v.value);
      };
      msg=msg.add([14, self.synthObj.nodeID] ++ mapArr);
		};

		msg;
	},

  runSynth: {|self, run|
    (self.synthObj.notNil).if({ self.synthObj.run(run) });
    self.run=run;
  },

  stopSynth: {|self|
    if(self.synthObj.notNil) {
      self.synthObj.free;
      self.synthObj=nil;
    };
  },

  releaseSynth: {|self|
    if (self.synthObj.notNil) {
      self.synthObj.release;
      self.synthObj=nil;
    };
  },

  setArgs: {|self ...args|
    args = args.asArray;

    "".postln;
    self.synthDefName.postln;
    "---".postln;
    "args: ".post;
    args.postln;

    "synthargs: ".post;
    self.synthArgDictionary.postln;

    "bus: ".post;
    self.busDictionary.postln;

    if((self.busDictionary.notNil), {
      if(self.synthArgDictionary.isNil) { self.synthArgDictionary = Dictionary.new; };

      forBy(0, args.size - 2, 2, {|count|
        if((self.busDictionary.includesKey(args[count])), {
          "setting via bus ".post;
          self.busDictionary.at(args[count]).post;
          " ".post;
          args[count + 1].postln;

          self.server.sendMsg(\c_set,
            self.busDictionary.at(args[count]),
            args[count + 1]
          );
        }, {
            "no setting via bus".postln;
            self.synthObj.set(args[count], args[count + 1]);
            self.synthArgDictionary.put(args[count], args[count + 1]);
        })
      })
    }, {
      'Busses not initialized.'.postln;
    });
    self.synthObj;
  },

  setArgArray: {|self ...args|
    args = args.asArray;
    if((self.busDictionary.notNil), {
      (self.synthArgDictionary.isNil).if({
        self.synthArgDictionary=Dictionary.new;
      });

      forBy(0, args.size - 2, 2, {|count|
        (self.busDictionary.includesKey(args[count])).if({
          self.server.sendMsg(\c_setn,
            self.busDictionary.at(args[count]),
            args[count + 1].size,
            args[count + 1]
          );
          }, {
            self.synthObj.setn(args[count], args[count + 1]);
        })
      })
      }, {
        'Busses not initialized.'.postln;
    });
    self.synthObj;
  },

  getValues: {|self, func|
		self.busarr.getn(self.busDictionary.size,
			{|busses|
				func.value([busses, self.synthArgDictionary]);
			}
		);
	},

  map: {|self ...args|
		forBy(0, args.size-2, 2, {|i|
			self.nodeMap.map(args[i], args[i + 1]);
		});
		if(self.synthObj.notNil) {
			self.nodeMap.sendToNode(self.synthObj);
		};
		self.nodeMap;
	},
);

~buildGui = (
	reproduce: {|self|
		var copy;
		copy=self.copy;
		copy.valueDictionary=self.valueDictionary.copy;
		copy.hasGui=false;
		copy;
	},
	valueDictionary: nil,
	hasGui: false,
	showIO: false,
	linkIncDec: true,
	elementStyle: (
		knobSize: 40@85,
		textWidth: 40,
		textHeight: 16,
		buttonSize: 40 @ 16,
		smallButtonSize: 16 @ 16,
		sliderSize: 200 @ 18,
		sliderLabel: 40,
		sliderNumber: 40,
		boxSize: 40 @ 16,
		smallBoxSize: 18 @ 16,
		popupSize: 68@18,
		bgcolor: Color.white
	),
	makeGui: nil,

	displayGui: {|self, parent, title=\Synth|
    var w, v, newwin;

    if(parent.isNil) {
      w = MultiPageLayout.new(title, nil, 10@0, false);
      newwin=true;
      w.view.background_(self.elementStyle.bgcolor);
      } {
        w = parent;
        newwin = false;
    };

    w.flow({|v|
      self.makeGui(v);
    });


    self.setValues;
    if (newwin) {
      w.resizeToFit;
      w.front;
    };

    self.hasGui=true;
    w.onClose_({ self.valueDictionary=self.getValues; self.hasGui=false });
	},

	setValues: {|self, dict|
		dict=dict ? self.valueDictionary;
		(dict.notNil).if({
			dict.keysValuesDo({|key, value|
				(self.elementDictionary.at(key).notNil).if({
					(value.isKindOf(Dictionary)).if({
						value.keysValuesDo({|vkey, vval|
							try { self.elementDictionary.at(key).perform(vkey, vval) };
						});
					}, {
						((self.elementDictionary.at(key).isKindOf(EZSlider)) ||
							(self.elementDictionary.at(key).isKindOf(EZKnob))).if({
							try { self.elementDictionary.at(key).value_(value) };
						}, {
							try { self.elementDictionary.at(key).valueAction_(value) };
						});
					});
				});
			});
		});
	},
	getValues: {|self|
		var outputDictionary;
		outputDictionary=Dictionary.new;
		self.elementDictionary.keysValuesDo({|key, value|
			// some special cases.    could be expanded
			((value.isKindOf(RangeSlider)) || (value.isKindOf(Slider2D)) ||
				(value.isKindOf(Function))).if({
				switch (value.class)
				{ RangeSlider } {
					outputDictionary.add(key ->
						Dictionary[\activeLo_ -> value.lo, \activeHi_ -> value.hi]
					);
				}
				{ Slider2D } {
					outputDictionary.add(key ->
						Dictionary[\activex_ -> value.x, \activey_ -> value.y]
					);
				}
				{ Function } {
					outputDictionary.add(key ->
						Dictionary[\value -> value.value]
					);
				};
			}, {
				(value.isKindOf(EnvEditor)).if({
					outputDictionary.add(key -> value.env.deepCopy);
				}, {
					outputDictionary.add(key -> value.value);
				});
			});
		});
		outputDictionary;
	},

	updateMIDI: {|self ...args|
		(self.midiObj.notNil).if({
			args=args.asArray;
			forBy(0, args.size-2, 2, {|i|
				try {
					self.midiObj.updateValue(
						self.midiObj.ccDictionary.matchAt(args[i]),
						args[i + 1]
					);
				}
			});
		});
	}
);

~incDecMidi = (
	reproduce: {|self|
		var copy;
		copy=self.copy;
		copy
	},
	guiObj: nil,
	src: nil,
	chan: nil,
	nums: nil,
	ccDictionary: nil,
	valueDictionary: nil,
	updateValue: {|self, cc, val|
		self.responderObj.updateValue(cc, val);
	},
	responderDo: {|self, action ...args|
		self.responderObj.perform(action, args);
	},
	updateGui: {|self, key, val, perform=\value_|
		(self.guiObj.notNil).if({
			try {
				{ self.guiObj.elementDictionary.at(key).perform(perform, val); }.defer
			};
		});
	},
	removeResponder: {|self|
		self.responderObj.remove;
	},
	initialize: {|self|
		self.makeResponder.value;
		CmdPeriod.doOnce({
			self.responderObj.remove;
		});
	},
	makeResponder: nil
);
)
