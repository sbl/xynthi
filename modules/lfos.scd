(
// build synthDef, synthObj, gui, midiCtrls

// synthDef //
SynthDef(\lfo_sine, {
  |out=0, freq=1, i_phase=0, amp=1|
  Out.kr(out,
    LFCub.kr(freq, i_phase, amp)
  )
}
).send(s);

SynthDef(\lfo_saw, {
  |out=0, freq=1, i_phase=0, amp=1|
  Out.kr(out,
    LFSaw.kr(freq, i_phase, amp)
  )
}
).send(s);

SynthDef(\lfo_pulse, {
  |out=0, freq=1, i_phase=0, pw=0.5, amp=1, add=0|
  Out.kr(out,
    LFPulse.kr(freq, i_phase, pw, amp, add)
  )
}
).send(s);

SynthDef(\lfo_sh, {
  |out=0, freq=1, amp=1|
  Out.kr(out,
    LFDNoise0.kr(freq, amp)
  )
}
).send(s);

SynthDef(\lfo_jitter, {
  |out=0, freq=1, amp=1|
  var dust;
  dust=Dust2.kr(freq, 0.0334);
  Out.kr(out,
    LFDNoise3.kr(freq.ring1(Latch.kr(dust, dust.abs)), amp)
  )
}
).send(s);

SynthDef(\lfo_dust, {
  |out=0, freq=1, amp=1|
  var dust;
  dust=Dust2.kr(freq, amp);
  Out.kr(out, Latch.kr(dust, dust.abs))
}).send(s);

SynthDef(\lfo_bdust, {
  |out=0, freq=1, amp=1|
  var dust;
  dust=Dust2.kr(freq);
  Out.kr(out, TBrownRand.kr(amp.neg, amp, 1.0, 1, dust.abs))
}).send(s);

// synthObj //
~lfoSynth=~busControlledSynth.reproduce;
~lfoSynth.synthDefName=\lfo_sine;
~lfoSynth.fastPlay=false;
~lfoSynth.defaultSettings=[1, 0.5];
~lfoSynth.makeBusDictionary={|self|
  var busarr, rootIndex;
  busarr=Bus.control(self.server, 2);
  self.busarr=busarr;
  busarr.setn(self.defaultSettings);
  rootIndex=busarr.index;
  self.busDictionary=Dictionary[
    \freq -> rootIndex,
    \pw -> (rootIndex + 1)
  ];
};
// gui //
~lfoGui=~buildGui.reproduce;
~lfoGui.synthObj=~lfoSynth;
~lfoGui.makeGui={|self, w|
  var synths, popStates, vert;
  synths=[\lfo_sine, \lfo_saw, \lfo_saw, \lfo_pulse, \lfo_pulse, \lfo_sh, \lfo_jitter, \lfo_dust, \lfo_bdust];
  popStates=["Sine", "Saw Up", "Saw Down", "Pulse", "Pulse2", "SH", "Jitter", "Dust", "BDust"];
  self.elementDictionary=Dictionary[
    \synth ->
    PopUpMenu(w, self.elementStyle.popupSize)
    .items_(popStates)
    .action_({|v|
      var synthArgs;
      synthArgs=[\out, self.synthObj.outbus.index];
      self.synthObj.stopSynth;
      (v.value==2).if({
        synthArgs=synthArgs ++ [\amp, -1];
      }, {
        (v.value==4).if({
          synthArgs=synthArgs ++ [\amp, 2, \add, -1];
        });
      });
      self.synthObj.synthDefName=synths.at(v.value);
      self.synthObj.playSynth(synthArgs);
    })
  ];
  w.startRow;
  self.elementDictionary.putAll(Dictionary[
    \freq ->
    EZKnob.new(w, self.elementStyle.knobSize, 'freq', [0.033, 60, \exp],
      action: {|v|
        self.synthObj.setArgs(\freq, v.value);
        self.updateMIDI(\freq, v.value);
      },
      layout: \vert2
    )
  ]);
  w.vert({|v|
    self.elementDictionary.putAll(Dictionary[
      \play ->
      ToggleButton(v, " P ", { self.synthObj.playSynth }, { self.synthObj.stopSynth }).view,
      \mute ->
      ToggleButton(v, " M ", { self.synthObj.runSynth(false) }, { self.synthObj.runSynth(true) }).view
    ]);
    (self.showIO).if({
      self.elementDictionary.put(\out,
        NumberBox(v, self.elementStyle.smallBoxSize)
        .action_({|v| self.synthObj.setArgs(\out, v.value) })
        .canFocus_(false);
      );
    });
  }, 20@100)
};
~lfoGui.valueDictionary=Dictionary[
  \synth -> 0,
  \freq -> 1,
  \mute -> 0,
  \play -> 1
];

// MIDI
~lfoMidi = ~incDecMidi.reproduce;
~lfoMidi.guiObj=~lfoGui;
~lfoMidi.valueDictionary=Dictionary[\freq -> 1, \pw -> 0.5];
~lfoMidi.synthObj=~lfoSynth;
~lfoMidi.makeResponder={|self|
  self.responderObj=IncDecResponderBank(
    self.src,
    self.chan,
    self.ccDictionary.at(\freq), 0.0078, [0.033, 60, \exp],
    {|s, c, n, v|
      self.synthObj.setArgs(\freq, v);
      self.updateGui(\freq, v, \valueNoAction_);
    },
    self.valueDictionary.at(\freq),
    self.ccDictionary.at(\pw), 0.0078, \unipolar,
    {|s, c, n, v|
      self.synthObj.setArgs(\pw, v);
    },
    self.valueDictionary.at(\pw)
  );
  self.responderObj;
};
~lfoInstr=(
  reproduce: {|self|
    var newSelf;
    newSelf=self.copy;
    newSelf.theSynth=self.theSynth.reproduce(true);
    newSelf.theSynth.outbus=Bus.control;
    newSelf.theGui=self.theGui.reproduce;
    newSelf.theGui.valueDictionary.put(\out, newSelf.theSynth.outbus.index);
    newSelf.theGui.synthObj=newSelf.theSynth;
    newSelf.theMidi=self.theMidi.reproduce;
    newSelf.theMidi.synthObj=newSelf.theSynth;
    newSelf.theMidi.guiObj=newSelf.theGui;
    newSelf;
  },
  theSynth: ~lfoSynth,
  theGui: ~lfoGui,
  theMidi: ~lfoMidi,
  midiOn: {|self|
    self.theGui.midiObj=self.theMidi;
  }
);
// ~lfoGui.displayGui(~lfoWin, \lfo);
)
