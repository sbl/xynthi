(
// build synthDef, synthObj, gui, midiCtrls

// synthDef //

SynthDef(\tone_out, {|out=0, in=38, tone=0.5, pan=0, amp=1|
	var input;
	input=In.ar(in);
	input=Tone.ar(input * amp, Clip.kr(tone, 0.01, 1.0));
	// input=Limiter.ar(input * amp, 0.99, 0.01);
	Out.ar(out, Pan2.ar(input, pan))
}, [nil, nil, 0.02, 0.02, 0.02]).add;

// synthObj //
~output=~busControlledSynth.reproduce;
~output.synthDefName=\tone_out;
~output.fastPlay=false;
~output.defaultSettings=[0.5, 0, 1];
~output.makeBusDictionary={|self|
	var bus;
	bus=Bus.control(s, 3);
	self.busDictionary=Dictionary[
		\tone -> bus.index,
		\pan -> (bus.index + 1),
		\amp -> (bus.index + 2)
	];
	bus.set(self.defaultSettings);
	self.busarr=bus;
};

// gui //
~outputGui = ~buildGui.reproduce;
~outputGui.synthObj = ~output;

~outputGui.makeGui = {|self, w|
	self.elementDictionary=Dictionary.new;
	(self.showIO).if({
		w.vert({|v|
			self.elementDictionary.putAll(Dictionary[
				\in ->
				NumberBox(v, self.elementStyle.smallBoxSize)
					.action_({|v| self.synthObj.setArgs(\in, v.value) }),
				\out ->
				NumberBox(v, self.elementStyle.smallBoxSize)
					.action_({|v| self.synthObj.setArgs(\out, v.value) })
			]);
		}, 30@40);
	});

	self.elementDictionary.putAll(Dictionary[
		\tone ->
		EZKnob.new(w, self.elementStyle.knobSize, 'tone', \unipolar,
			action: {|v|
				self.synthObj.setArgs(\tone, v.value);
				self.updateMIDI(\tone, v.value);
			},
      layout: \vert2
		),
		\pan ->
		EZKnob.new(w, self.elementStyle.knobSize, 'pan', \pan,
			action: {|v|
				self.synthObj.setArgs(\pan, v.value);
				self.updateMIDI(\pan, v.value);
			},
      layout: \vert2
		),
		\amp ->
		EZKnob.new(w, self.elementStyle.knobSize, 'amp', [0, 2, 2],
			action: {|v|
				self.synthObj.setArgs(\amp, v.value);
				self.updateMIDI(\amp, v.value);
			},
      layout: \vert2
		)
	]);

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

~outputGui.valueDictionary=Dictionary[
	\in-> 38,
	\tone -> 0.5,
	\pan -> 0.0,
	\out -> 0,
	\amp -> 1,
	\mute -> 0,
	\play -> 1
];

// MIDI
~outputMidi = ~incDecMidi.reproduce;
~outputMidi.synthObj=~outputSynth;
~outputMidi.guiObj=~outputGui;
~outputMidi.valueDictionary=~outputGui.valueDictionary.copy;
~outputMidi.makeResponder={|self|
	self.responderObj=IncDecResponderBank(
		self.src,
		self.chan,
		self.ccDictionary.at(\tone), 0.0078, \unipolar,
			{|s, c, n, v|
				self.synthObj.setArgs(\tone, v);
				self.updateGui(\tone, v, \valueNoAction_);
			},
			self.valueDictionary.at(\tone),
		self.ccDictionary.at(\pan), 0.0078, \pan,
			{|s, c, n, v|
				self.synthObj.setArgs(\pan, v);
				self.updateGui(\pan, v, \valueNoAction_);
			},
			self.valueDictionary.at(\pan),
		self.ccDictionary.at(\amp), 0.0078, [0, 2, 1],
			{|s, c, n, v|
				self.synthObj.setArgs(\amp, v);
				self.updateGui(\amp, v, \valueNoAction_);
			},
			self.valueDictionary.at(\amp)
	);
	self.responderObj;
};

~outputInstr=(
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
	theSynth: ~output,
	theGui: ~outputGui,
	theMidi: ~outputMidi,
	midiOn: {|self|
		self.theGui.midiObj=self.theMidi;
	}
)
)