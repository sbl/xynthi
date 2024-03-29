(
// build synthDef, synthObj, gui, midiCtrls

// synthDef //
SynthDef(\ac_env, {|in=10, out=0, ctrl_out=32, timescale=1, mul=2, add= -1, gate=1|
  var env, envelope;
  env=Control.names([\env]).kr(Env.newClear(9).asArray);
  envelope=EnvGen.kr(env, gate, timeScale:timescale);
  Out.kr(ctrl_out, envelope * mul + add);
  Out.ar(out, In.ar(in) * envelope);
}).send(s);

SynthDef(\ctrl_env, {|ctrl_out=32, timescale=1, mul=2, add= -1, gate=1|
  var env, envelope;
  env=Control.names([\env]).kr(Env.newClear(9).asArray);
  envelope=EnvGen.kr(env, gate, timeScale:timescale);
  Out.kr(ctrl_out, envelope * mul + add);
}).send(s);

// synthObj //
~envSynth=~busControlledSynth.reproduce;
~envSynth.synthDefName=\ac_env;
~envSynth.fastPlay=false;
~envSynth.defaultSettings=[1, 1];
~envSynth.makeBusDictionary={|self|
  var busarr, rootIndex;
  busarr=Bus.control(self.server, 2);
  self.busarr=busarr;
  busarr.setn(self.defaultSettings);
  rootIndex=busarr.index;
  self.busDictionary=Dictionary[
    \timescale -> rootIndex,
    \gate -> (rootIndex + 1)
  ];
};

~envSynth.env = Env([0.0, 1.0, 0.5, 0.5, 0.0], [0.02, 0.1, 0.78, 0.1], [0, 0, 0, 0], 3, 0);

// gui //
~envGui = ~buildGui.reproduce;
~envGui.synthObj = ~envSynth;

// FIXME(sbl): out-commented
// ~envGui.resetenv={|self|
//   self.elementDictionary.at(\env).refresh(self.synthObj.env);
// };

~envGui.makeGui={|self, w|
  var envView;

  self.elementDictionary = Dictionary[
    \mode ->
    ToggleButton(w, " Loop ", {
      self.synthObj.env.loopNode=self.elementDictionary.at(\loop).value;
      self.synthObj.setArgArray(\env, self.synthObj.env.asArray);
      self.synthObj.busarr.getn(2, {|v|
        (v[1]==1).if({
          self.synthObj.setArgs(\gate, 0);
          { self.synthObj.setArgs(\gate, 1) }.defer(0.1);
        });
      });
    }, {
      self.synthObj.env.loopNode=nil;
      self.synthObj.setArgArray(\env, self.synthObj.env.asArray);
      self.resetenv;
    }).view,

    \loop ->
    NumberBox(w, 20@18)
    .action_({|v|
      (self.elementDictionary.at(\mode).value==1).if({
        self.synthObj.env.loopNode=v.value;
        self.synthObj.setArgArray(\env, self.synthObj.env.asArray);
        self.resetenv;
      });
    }),

    \release ->
    NumberBox(w, 20@18)
    .action_({|v|
      var val;

      val = min(v.value, self.synthObj.env.levels.size);
      self.synthObj.env.releaseNode=val;
      self.synthObj.setArgArray(\env, self.synthObj.env.asArray);
      self.synthObj.stopSynth;
      self.synthObj.playSynth;
      self.synthObj.setArgArray(\env, self.synthObj.env.asArray);
      self.resetenv;
    }),

    \gate ->
    ToggleButton(w, " Gate ", { self.synthObj.setArgs(\gate, 1) },
      { self.synthObj.setArgs(\gate, 0) }).view
  ];


  ActionButton(w, " - ", {
    var levels, times, curves, releaseNode;
    levels=self.synthObj.env.levels.asArray;
    levels.pop;
    times=self.synthObj.env.times.asArray;
    times.pop;
    times=times.normalizeSum;
    curves=self.synthObj.env.curves.asArray;
    curves.pop;
    (self.synthObj.env.releaseNode.notNil).if({
      releaseNode=self.synthObj.env.releaseNode.min(levels.size - 2);
    }, {
      releaseNode=nil;
    });

    self.elementDictionary.at(\release).value_(releaseNode);

    self.synthObj.env=Env(levels, times, curves, releaseNode, self.synthObj.env.loopNode);
    self.synthObj.setArgArray(\env, self.synthObj.env.asArray);
    self.synthObj.stopSynth;
    self.synthObj.playSynth;
    self.synthObj.setArgArray(\env, self.synthObj.env.asArray);
    self.resetenv(w);
  });

  ActionButton(w, " + ", {
    var levels, times, curves, releaseNode;
    levels=self.synthObj.env.levels.asArray;
    times=self.synthObj.env.times.asArray;
    curves=self.synthObj.env.curves.asArray;
    releaseNode=self.synthObj.env.releaseNode;
    (releaseNode.notNil).if({ releaseNode=releaseNode + 1 });
    self.synthObj.env=Env(levels ++ 0,
      (times ++ times.at(times.size-1)).normalizeSum,
      curves ++ curves.at(curves.size-1),
      releaseNode,
      self.synthObj.env.loopNode
    );
    self.synthObj.stopSynth;
    self.synthObj.playSynth;
    self.synthObj.setArgArray(\env, self.synthObj.env.asArray);
    self.resetenv;
    self.elementDictionary.at(\release).value_(releaseNode);
  });

  w.startRow;
  envView = EnvelopeView(w, 255@84);
  envView.setEnv(self.synthObj.env);

  // FIXME(sbl): likely broken
  envView.action = {|env|
    (env != self.synthObj.env).if({
      self.synthObj.stopSynth;
      self.synthObj.env = env;
      self.synthObj.playSynth;
      self.synthObj.setArgArray(\env, self.synthObj.env.asArray);
    }, {
      self.synthObj.setArgArray(\env, self.synthObj.env.asArray)
    })
  };
  self.elementDictionary.put(\env, self.synthObj.env);

  w.startRow;

  self.elementDictionary.putAll(Dictionary[
    \timescale ->
    NumberBox(w, 33@18)
    .clipLo_(0.01)
    .clipHi_(30)
    .step_(0.02)
    .action_({|v| self.synthObj.setArgs(\timescale, v.value) }),

    \play ->
    ToggleButton(w, " P ", {
      self.synthObj.playSynth;
      self.synthObj.setArgArray(\env, self.synthObj.env.asArray);

    }, { self.synthObj.stopSynth }).view,
    \mute ->
    ToggleButton(w, " M ", { self.synthObj.runSynth(false) }, { self.synthObj.runSynth(true) }).view,
  ]);

  if (self.showIO) {
    self.elementDictionary.put(\k_out,
      NumberBox(w, self.elementStyle.smallBoxSize)
      .canFocus_(false);
    );
    self.elementDictionary.put(\out,
      NumberBox(v, self.elementStyle.smallBoxSize)
      .action_({|v| self.synthObj.setArgs(\out, v.value) })
    );
    self.elementDictionary.put(\in,
      NumberBox(v, self.elementStyle.smallBoxSize)
      .action_({|v| self.synthObj.setArgs(\in, v.value) })
    );
  };

  ActionButton(w, " S ", {
    Dialog.savePanel({|path|
      var dict;
      dict=self.getValues;
      dict.writeTextArchive(path);
    })
  });

  ActionButton(w, " L ", {
    Dialog.getPaths({|path|
      self.valueDictionary=Object.readTextArchive(path[0]);
      self.setValues;
    })
  })
};

~envGui.setValues = {|self, argdict|
  var dict, loop, release, mode;


  (argdict.notNil).if({
    dict=argdict.deepCopy;
  }, {
    dict=self.valueDictionary.deepCopy;
  });


  if (dict.notNil) {
    loop = dict.removeAt(\loop);
    release = dict.removeAt(\release);
    mode = dict.removeAt(\mode);

    dict.keysValuesDo {|key, value|
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
            try {
              self.elementDictionary.at(key).valueAction_(value)
            };
          });
        });
      });
    };

    self.elementDictionary.at(\loop).valueAction_(loop);
    self.elementDictionary.at(\release).valueAction_(release);
    self.elementDictionary.at(\mode).valueAction_(mode);
  };


};

~envGui.valueDictionary=Dictionary[
  \mode -> 1,
  \in -> 32,
  \out -> 0,
  \loop -> 0,
  \play -> 1,
  \mute -> 0,
  \release -> 3,
  \gate -> 1,
  \timescale -> 1,
  \env -> ~envGui.synthObj.env
];

// MIDI
~envMidi = ~incDecMidi.reproduce;
~envMidi.guiObj=~envGui;
~envMidi.nums=88;
~envMidi.ccDictionary=Dictionary[
  \timescale -> 88
];
~envMidi.valueDictionary=Dictionary[\timescale -> 1];
~envMidi.synthObj=~envSynth;
~envMidi.makeResponder={|self|
  self.responderObj=IncDecResponderBank(
    self.src,
    self.chan,
    self.ccDictionary.at(\timescale), 0.0078, [0.1, 30, 6],
    {|s, c, n, v|
      self.synthObj.setArgs(\timescale, v);
      self.updateGui(\timescale, v);
    },
    self.valueDictionary.at(\timescale)
  );
  self.responderObj;
};
~envInstr=(
  reproduce: {|self|
    var newSelf;
    newSelf=self.copy;
    newSelf.theSynth=self.theSynth.reproduce(true);
    newSelf.theSynth.outbus=Bus.control;
    newSelf.theSynth.env=self.theSynth.env.copy;
    newSelf.theGui=self.theGui.reproduce;
    newSelf.theGui.valueDictionary.put(\out, newSelf.theSynth.outbus.index);
    newSelf.theGui.synthObj=newSelf.theSynth;
    newSelf.theMidi=self.theMidi.reproduce;
    newSelf.theMidi.synthObj=newSelf.theSynth;
    newSelf.theMidi.guiObj=newSelf.theGui;
    newSelf;
  },
  theSynth: ~envSynth,
  theGui: ~envGui,
  theMidi: ~envMidi,
  midiOn: {|self|
    self.theGui.midiObj=self.theMidi;
  }
);
)