(

// build synthDef, synthObj, gui, midiCtrls

// synthDef //

SynthDef(\noise_white, {|out=0, amp=1|
	Out.ar(out, WhiteNoise.ar(amp))
}).add;

SynthDef(\noise_pink, {|out=0, amp=1|
	Out.ar(out, PinkNoise.ar(amp))
}).add;

SynthDef(\noise_brown, {|out=0, amp=1|
	Out.ar(out, BrownNoise.ar(amp))
}).add;

SynthDef(\noise_gray, {|out=0, amp=1|
	Out.ar(out, GrayNoise.ar(amp))
}).add;

SynthDef(\noise_clip, {|out=0, amp=1|
	Out.ar(out, WhiteNoise.ar(amp))
}).add;

// synthObj //
~noise = ~busControlledSynth.reproduce;
~noise.synthDefName=\noise_white;
~noise.fastPlay=false;
~noise.defaultSettings=1;
~noise.makeBusDictionary={|self|
	var bus;
	bus = Bus.control;
	self.busDictionary = Dictionary[
		\amp -> bus.index
	];
	bus.set(self.defaultSettings);
	self.busarr = bus;
};

// gui //
~noiseGui = ~buildGui.reproduce;
~noiseGui.synthObj=~noise;
~noiseGui.makeGui={|self, w|

  var noises;
	noises = [\white, \pink, \brown, \gray, \clip];
	self.elementDictionary = Dictionary[
		\noisetype ->
		PopUpMenu(w, self.elementStyle.popupSize)
			.items_(noises)
			.action_({|v|
				self.synthObj.stopSynth;
				self.synthObj.synthDefName=\noise_ ++ noises.at(v.value);
				self.synthObj.playSynth;
			})
	];

	w.startRow;
	self.elementDictionary.put(
		\amp,
		EZKnob.new(w, self.elementStyle.knobSize, 'amp', \amp,
			{|v|
				self.synthObj.setArgs(\amp, v.value);
				self.updateMIDI(\amp, v.value);
			},
      layout: \vert2
		)
	);
	w.vert({|v|
		self.elementDictionary.putAll(Dictionary[
			\play ->
			ToggleButton(v, " P ", {
				self.synthObj.playSynth;
			}, {
				self.synthObj.stopSynth;
			}).view,
			\mute ->
			ToggleButton(v, " M ", {
				self.synthObj.runSynth(false);
			}, {
				self.synthObj.runSynth(true);
			}).view
		]);
		(self.showIO).if({
			self.elementDictionary.put(\out,
				NumberBox(v, self.elementStyle.smallBoxSize)
					.action_({|v| self.synthObj.setArgs(\out, v.value) })
			)
		});
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
};

~noiseGui.valueDictionary = Dictionary[
	\noisetype -> 0,
	\out -> 0,
	\amp -> 0.1,
	\mute -> 1,
	\play -> 1
];

// MIDI
~noiseMidi = ~incDecMidi.reproduce;
~noiseMidi.synthObj=~noiseSynth;
~noiseMidi.guiObj=~noiseGui;
~noiseMidi.valueDictionary=~noiseGui.valueDictionary.copy;
~noiseMidi.makeResponder={|self|
	self.responderObj=IncDecResponderBank(
		self.src,
		self.chan,
		self.ccDictionary.at(\amp), 0.0078, \amp,
			{|s, c, n, v|
				self.synthObj.setArgs(\amp, v);
				self.updateGui(\amp, v, \valueNoAction_);
			},
			self.valueDictionary.at(\amp)
	);
	self.responderObj;
};

~noiseInstr=(
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
	theSynth: ~noise,
	theGui: ~noiseGui,
	theMidi: ~noiseMidi,
	midiOn: {|self|
		self.theGui.midiObj=self.theMidi;
	}
)
)
