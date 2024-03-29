(
// build synthDef, synthObj, gui, midiCtrls

// synthDef //
// master frequency
SynthDef(\master_freq, {|out=0, freq_in=440, tune=1, lag=0.02|
  Out.kr(out, Lag.kr(freq_in * tune, lag));
}
).add;

// sine
SynthDef(\vco_sine, {|out=0, freq=440, tune=1, fm_in=37, fm=0, amp=1|
  Out.ar(out, SinOsc.ar(K2A.ar(freq * tune).ring1(In.ar(fm_in) * fm), 0, amp));
}, [nil, 0.02, 0.02, nil, nil, 0.02]
).add;

// varsaw
SynthDef(\vco_saw, {|out=0, freq=440, tune=1, fm_in=37, fm=0, pw=0.5, amp=1|
  Out.ar(out, VarSaw.ar(Clip.ar(K2A.ar(freq * tune).ring1(In.ar(fm_in) * fm), 0.1, 20000), 0, pw, amp));
}, [nil, 0.02, 0.02, nil, nil, 0.02, 0.02]
).add;

SynthDef(\vco_pulse, {|out=0, freq=440, tune=1, fm_in=37, fm=0, pw=0.5, amp=1|
  Out.ar(out, Pulse.ar(Clip.ar(K2A.ar(freq * tune).ring1(In.ar(fm_in) * fm), 0.1, 20000), pw, amp));
}, [nil, 0.02, 0.02, nil, nil, 0.02, 0.02]
).add;

SynthDef(\vco_pulself, {|out=0, freq=440, tune=1, fm_in=37, fm=0, pw=0.5, amp=1|
  Out.ar(out, LFPulse.ar(Clip.ar(K2A.ar(freq * tune).ring1(A2K.kr(In.ar(fm_in)) * fm), 0.1, 20000), 0.0, pw, amp));
}, [nil, 0.02, 0.02, nil, nil, 0.02, 0.02]
).add;

// sync saw
SynthDef(\vco_ssync, {|out=0, freq=440, tune=1, fm_in=37, fm=0, amp=1|
  var basefreq;
  basefreq=Clip.ar(K2A.ar(freq).ring1(In.ar(fm_in) * fm), 0.1, 20000);
  Out.ar(out, SyncSaw.ar(basefreq, (freq * tune), amp));
}, [nil, 0.02, 0.02, nil, nil, 0.02]
).add;

// synthObj //
~masterFreq = ~busControlledSynth.reproduce;
~masterFreq.synthDefName = \master_freq;
~masterFreq.fastPlay=false;
~masterFreq.defaultSettings=[440, 1, 0.02];
~masterFreq.makeBusDictionary={|self|
  var busarr, rootIndex;
  busarr = Bus.control(self.server, 3);
  rootIndex = busarr.index;
  self.busDictionary = Dictionary[
    \freq_in -> rootIndex,
    \tune -> (rootIndex + 1),
    \lag -> (rootIndex + 2)
  ];
  busarr.setn(self.defaultSettings);
  self.busarr = busarr;
  self.outbus = Bus.control;
  self.synthArgDictionary = Dictionary[\out -> self.outbus.index];
};

~vcoSynth=~busControlledSynth.reproduce;
~vcoSynth.synthDefName=\vco_sine;
~vcoSynth.fastPlay=false;
~vcoSynth.defaultSettings=[440, 1, 0, 0.5, 1];
~vcoSynth.makeBusDictionary={|self|
  var busarr, rootIndex;

  if((self.masterFreq.isNil), {
    busarr=Bus.control(self.server, 5);
    rootIndex=busarr.index;
    self.busDictionary=Dictionary[
      \freq -> rootIndex,
      \tune -> (rootIndex + 1),
      \fm -> (rootIndex + 2),
      \pw -> (rootIndex + 3),
      \amp -> (rootIndex + 4)
    ];
    busarr.setn(self.defaultSettings);
  }, {
    busarr=Bus.control(self.server, 4);
    rootIndex=busarr.index;
    self.busDictionary=Dictionary[
      \freq -> self.masterFreq.outbus.index,
      \tune -> rootIndex,
      \fm -> (rootIndex + 1),
      \pw -> (rootIndex + 2),
      \amp -> (rootIndex + 3)
    ];
    busarr.setn(self.defaultSettings.copyRange(1, 4));
  });
  self.busarr=busarr;
};


/* ---- */
// gui //
~vcoGui = ~buildGui.reproduce;
~vcoGui.synthObj = ~vcoSynth;
~vcoGui.syncSaw=false;
~vcoGui.curspec=2;
~vcoGui.makeGui={|self, w|
  var vert, waves, freqRange, resSpec;

  if (self.linkIncDec) {
    resSpec=[0.0078, 0.0005, -1].asSpec;
    Slider(w, 10@80)
    .action_({|v|
      try {
        self.midiObj.responderObj.updateResolution(
          self.midiObj.ccDictionary.at(\freq), resSpec.map(v.value)
        );
      }
    })
    .thumbSize_(2);
  };

  // KNOBS

  self.elementDictionary = Dictionary();

  if (self.synthObj.masterFreq.isNil) {
    waves=[\sine, \saw, \pulse, \ssync, \pulself];
    self.elementDictionary.put(\freq,
      EZKnob.new(w, self.elementStyle.knobSize, 'freq', \freq,
        action: {|v|
          self.synthObj.setArgs(\freq, v.value);
          self.updateMIDI(\freq, v.value);
        },
        layout: \vert2
    ));
  } {
    waves=[\sine, \saw, \pulse, \pulself];
    self.elementDictionary.put(\freq,
      EZKnob.new(w, self.elementStyle.knobSize, 'freq', \freq,
        action: {|v|
          self.synthObj.masterFreq.setArgs(\freq_in, v.value);
          self.updateMIDI(\freq, v.value);
        },
        layout: \vert2
      )
    );
  };

  self.elementDictionary.put(\fm,
    EZKnob.new(w, self.elementStyle.knobSize, 'fm', [0, 32, 10],
      action: {|v|
        self.synthObj.setArgs(\fm, v.value);
        self.updateMIDI(\fm, v.value);
      },
      layout: \vert2,
  ));

  self.elementDictionary.put(\pw,
    EZKnob.new(w, self.elementStyle.knobSize, 'pw', \unipolar,
      action: {|v|
        self.synthObj.setArgs(\pw, v.value);
        self.updateMIDI(\pw, v.value);
      },
      layout: \vert2
  ));

  self.elementDictionary.put(\amp,
    EZKnob.new(w, self.elementStyle.knobSize, 'amp', \amp,
      action: {|v|
        self.synthObj.setArgs(\amp, v.value);
        self.updateMIDI(\amp, v.value);
      },
      layout: \vert2
  ));

  // Button row

  w.vert({|v|
    self.elementDictionary.putAll(Dictionary[
      \play ->
      ToggleButton(v, " P ", {
        self.synthObj.playSynth;
      }, {
        self.synthObj.stopSynth;
      }, false).view,
      \mute ->
      ToggleButton(v, " M ", {
        self.synthObj.runSynth(false);
      }, {
        self.synthObj.runSynth(true);
      }, false).view
    ]);

    if (self.showIO) {
      self.elementDictionary.put(\out,
        NumberBox(v, self.elementStyle.smallBoxSize)
        .action_({|v| self.synthObj.setArgs(\out, v.value) })
      )
    };
    ActionButton(v, " S ", {
      Dialog.savePanel({|path|
        var dict;
        dict=self.getValues;
        dict.writeTextArchive(path);
      })
    });
    ActionButton(v, " L ", {
      Dialog.getPaths({|path|
        self.valueDictionary=Object.readTextArchive(path[0]);
        self.setValues;
      })
    });
  }, 20@82);

  w.startRow;


  if (self.showIO) {
    self.elementDictionary.put(
      \fm_in,
      NumberBox(w, self.elementStyle.smallBoxSize)
      .action_({|v| self.synthObj.setArgs(\fm_in, v.value) })
    )
  };

  self.elementDictionary.putAll(Dictionary[
    \wave ->
    PopUpMenu(w, 50@18)
    .items_(waves)
    .action_({|v|
      var synthArgs, curval, newspec, newact;
      self.synthObj.stopSynth;
      self.synthObj.synthDefName=\vco_ ++ waves.at(v.value);
      self.synthObj.playSynth;

      if (waves.at(v.value) == \ssync) {
        self.syncSaw=true;
        self.elementDictionary.at(\sync).valueAction_(1);
        curval=self.elementDictionary.at(\freq).controlSpec.unmap(
          self.elementDictionary.at(\freq).value
        );
        newspec=[0, 64].asSpec;
        curval=newspec.map(curval);
        newact={|v|
          self.synthObj.setArgs(\tune, v.value.midiratio);
          self.updateMIDI(\freq, v.value);
        };
        self.elementDictionary.at(\freq).controlSpec_(newspec);
        self.elementDictionary.at(\freq).action_(newact);
        self.elementDictionary.at(\freq).value_(curval);
        (self.midiObj.notNil).if({
          newact={|s, c, n, v|
            self.midiObj.synthObj.setArgs(\tune, v.value.midiratio);
            self.midiObj.updateGui(\freq, v.value);
          };
          self.midiObj.responderObj.updateSpec(self.midiObj.ccDictionary.at(\freq), newspec);
          self.midiObj.responderObj.updateFunc(self.midiObj.ccDictionary.at(\freq), newact);
          self.midiObj.responderObj.updateValue(self.midiObj.ccDictionary.at(\freq), curval);
        });
      } /* else */ {
        (self.syncSaw).if({
          curval=self.elementDictionary.at(\freq).controlSpec.unmap(
            self.elementDictionary.at(\freq).value
          );
          newspec=[-36, 36].asSpec;
          curval=newspec.map(curval);
          self.elementDictionary.at(\freq).controlSpec_(newspec);
          self.elementDictionary.at(\freq).value_(curval);
          (self.midiObj.notNil).if({
            self.midiObj.responderObj.updateSpec(self.midiObj.ccDictionary.at(\freq), newspec);
            self.midiObj.responderObj.updateValue(self.midiObj.ccDictionary.at(\freq), curval);
          });
        });
        self.syncSaw=false;
      }
    }),
    \setRange ->
    {|v|
      var specs, names, curval;
      if (v.isNil) {
        self.curspec;
      } /* else */ {
        ((self.elementDictionary.includesKey(\sync).not) || (self.elementDictionary.at(\sync).value==0)).if({
          specs=[\lofreq.asSpec,
            ControlSpec(20, 1200, \exponential),
            \freq.asSpec,
            \widefreq.asSpec
          ];
          names=[\LFO, \Lo, \Full, \Wide];

          curval=self.elementDictionary.at(\freq)
          .controlSpec.unmap(self.elementDictionary.at(\freq).value);
          curval=specs.at(v).map(curval);
          self.elementDictionary.at(\freq).controlSpec_(specs.at(v));
          self.elementDictionary.at(\freq).value_(curval);
          freqRange.string_(names.at(v));
          self.curspec=v;

          if (self.midiObj.notNil) {
            self.midiObj.responderObj.updateSpec(self.midiObj.ccDictionary.at(\freq), specs.at(v));
            self.midiObj.responderObj.updateValue(self.midiObj.ccDictionary.at(\freq), curval);
          };
        });
      }
  }]);

  freqRange = StaticText(w, 28@18).string_(\Full);
  ActionButton(w, "L", {
    self.elementDictionary.at(\setRange).value(0);
  });
  ActionButton(w, "M", {
    self.elementDictionary.at(\setRange).value(1);
  });
  ActionButton(w, "F", {
    self.elementDictionary.at(\setRange).value(2);
  });
  ActionButton(w, "W", {
    self.elementDictionary.at(\setRange).value(3);
  });

  if (self.syncObj.notNil) {
    self.elementDictionary.put(\sync,
      ToggleButton(w, " ^ ", {
        var newspec, newact, curval;

        self.synthObj.map(\freq, self.syncObj.busDictionary.at(\freq));
        (self.elementDictionary.at(\wave).value==3).if({
          newspec=[0, 64].asSpec;
        }, {
          newspec=[-36, 36].asSpec;
        });
        newact={|v|
          self.synthObj.setArgs(\tune, v.value.midiratio);
          self.updateMIDI(\freq, v.value);
        };
        curval=self.elementDictionary.at(\freq).controlSpec.unmap(
          self.elementDictionary.at(\freq).value
        );
        curval=newspec.map(curval);
        self.elementDictionary.at(\freq).controlSpec_(newspec).action_(newact).value_(curval);
        (self.midiObj.notNil).if({
          newact={|s, c, n, v|
            self.midiObj.synthObj.setArgs(\tune, v.value.midiratio);
            self.midiObj.updateGui(\freq, v.value);
          };
          self.midiObj.responderObj.updateSpec(self.midiObj.ccDictionary.at(\freq), newspec);
          self.midiObj.responderObj.updateFunc(self.midiObj.ccDictionary.at(\freq), newact);
          self.midiObj.responderObj.updateValue(self.midiObj.ccDictionary.at(\freq), curval);
        });
      }, {
        var newspec, newact, curval;
        (self.elementDictionary.at(\wave).value==3).if({
          self.elementDictionary.at(\wave).valueAction_(1);
        });
        self.synthObj.map(\freq, self.synthObj.busDictionary.at(\freq));

        self.synthObj.setArgs(\tune, 1);
        newspec=\freq.asSpec;
        newact={|v|
          self.synthObj.setArgs(\freq, v.value);
          self.updateMidi(\freq, v.value);
        };
        curval=self.elementDictionary.at(\freq).controlSpec.unmap(
          self.elementDictionary.at(\freq).value
        );
        curval=newspec.map(curval);
        self.elementDictionary.at(\freq).controlSpec_(newspec).action_(newact).value_(curval);
        (self.midiObj.notNil).if({
          newact={|s, c, n, v|
            (self.synthObj.masterFreq.isNil).if({
              self.midiObj.synthObj.setArgs(\freq, v.value);
            }, {
              self.midiObj.synthObj.masterFreq.setArgs(\freq, v.value);
            });
            self.midiObj.updateGui(\freq, v.value);
          };
          self.midiObj.responderObj.updateSpec(self.midiObj.ccDictionary.at(\freq), newspec);
          self.midiObj.responderObj.updateFunc(self.midiObj.ccDictionary.at(\freq), newact);
          self.midiObj.responderObj.updateValue(self.midiObj.ccDictionary.at(\freq), curval);
        });
      }).view
    );
  };

};

~vcoGui.setValues={|self, argdict|
  var dict, newfreq;

  if (argdict.notNil) {
    dict=argdict.deepCopy;
  } {
    dict=self.valueDictionary.deepCopy;
  };

  if (dict.notNil) {
    newfreq=dict.removeAt(\freq);
    dict.keysValuesDo { |key, value|

      if (self.elementDictionary.at(key).notNil) {
        if (value.isKindOf(Dictionary)) {
          value.keysValuesDo {|vkey, vval|
            try { self.elementDictionary.at(key).perform(vkey, vval) };
          };
        }
        // else
        {
          if ((self.elementDictionary.at(key).isKindOf(EZSlider)) ||
            (self.elementDictionary.at(key).isKindOf(EZKnob))) {
            try {
              self.elementDictionary.at(key).value_(value)
            };
          }
          // else
          {
            try {
              self.elementDictionary.at(key).valueAction_(value)
            };
          };

        };
      };
    };


    self.elementDictionary.at(\freq).value_(newfreq);
    self.valueDictionary.put(\freq, newfreq);
  };

};

~vcoGui.valueDictionary=Dictionary[
  \freq -> 440,
  \fm -> 0,
  \pw -> 0.5,
  \amp -> 0.1,
  \fm_in -> 37,
  \wave -> 0,
  \out -> 0,
  \mute -> 1,
  \play -> 1,
  \setRange -> Dictionary[\value -> 2]
];

// MIDI
~vcoMidi = ~incDecMidi.reproduce;
~vcoMidi.synthObj=~vcoSynth;
~vcoMidi.guiObj=~vcoGui;
~vcoMidi.valueDictionary=~vcoGui.valueDictionary.copy;
~vcoMidi.makeResponder={|self|
  self.responderObj=IncDecResponderBank(
    self.src,
    self.chan,
    self.ccDictionary.at(\freq), 0.0078, \freq,
    {|s, c, n, v|
      (self.synthObj.masterFreq.isNil).if({
        self.synthObj.setArgs(\freq, v);
      }, {
        self.synthObj.masterFreq.setArgs(\freq_in, v);
      });
      self.updateGui(\freq, v, \valueNoAction_);
    },
    self.valueDictionary.at(\freq),
    self.ccDictionary.at(\fm), 0.0078, [0, 32, 10],
    {|s, c, n, v|
      self.synthObj.setArgs(\fm, v);
      self.updateGui(\fm, v, \valueNoAction_);
    },
    self.valueDictionary.at(\fm),
    self.ccDictionary.at(\pw), 0.0078, \unipolar,
    {|s, c, n, v|
      self.synthObj.setArgs(\pw, v);
      self.updateGui(\pw, v, \valueNoAction_);
    },
    self.valueDictionary.at(\pw),
    self.ccDictionary.at(\amp), 0.0078, \amp,
    {|s, c, n, v|
      self.synthObj.setArgs(\amp, v);
      self.updateGui(\amp, v, \valueNoAction_);
    },
    self.valueDictionary.at(\amp)
  );
  self.responderObj;
};

~vcoInstr=(
  reproduce: {|self|
    var newSelf;
    newSelf=self.copy;
    newSelf.theSynth=self.theSynth.reproduce(true);
    newSelf.theGui=self.theGui.reproduce;
    newSelf.theGui.synthObj=newSelf.theSynth;
    newSelf.theMidi=self.theMidi.reproduce;
    newSelf.theMidi.synthObj=newSelf.theSynth;
    newSelf.theMidi.guiObj=newSelf.theGui;
    newSelf;
  },
  theSynth: ~vcoSynth,
  theGui: ~vcoGui,
  theMidi: ~vcoMidi,
  midiOn: {|self|
    self.theGui.midiObj=self.theMidi;
  }
)
)
