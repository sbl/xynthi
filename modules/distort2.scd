(
// build synthDef, synthObj, gui, midiCtrls

// synthDef //
SynthDef(\bp_1, {|in=21, out=0|
		Out.ar(out, In.ar(in));
}).add;

SynthDef(\clip2, {|out=0, in=38, mod_in=39, depth=1|
	Out.ar(out, In.ar(in).clip2(In.ar(mod_in) * depth))
}).add;

SynthDef(\wrap2, {|out=0, in=38, mod_in=39, depth=1|
	Out.ar(out, In.ar(in).wrap2(In.ar(mod_in) * depth))
}).add;

SynthDef(\fold2, {|out=0, in=38, mod_in=39, depth=1|
	Out.ar(out, In.ar(in).fold2(In.ar(mod_in) * depth))
}).add;

SynthDef(\excess, {|out=0, in=38, mod_in=39, depth=1|
	Out.ar(out, In.ar(in).excess(In.ar(mod_in) * depth))
}).add;

// synthObj //
~distort2=~busControlledSynth.reproduce;
~distort2.synthDefName=\clip2;
~distort2.fastPlay=false;
~distort2.defaultSettings=1;
~distort2.makeBusDictionary={|self|
	var bus;
	bus=Bus.control;
	self.busDictionary=Dictionary[
		\depth -> bus.index
	];
	bus.set(self.defaultSettings);
	self.busarr=bus;
};

// gui //
~distort2Gui=~buildGui.reproduce;
~distort2Gui.synthObj=~distort2;
~distort2Gui.makeGui={|self, w|
	var rings;
	rings=[\clip2, \fold2, \wrap2, \excess];
	self.elementDictionary=Dictionary[
		\disttype ->
		PopUpMenu(w, self.elementStyle.popupSize)
			.items_(rings)
			.action_({|v|
				self.synthObj.stopSynth;
				self.synthObj.synthDefName=rings.at(v.value);
				self.synthObj.playSynth;
			})
	];
	w.startRow;

	(self.showIO).if({
		w.vert({|v|
			self.elementDictionary.putAll(Dictionary[
				\in ->
				NumberBox(v, self.elementStyle.smallBoxSize)
					.action_({|v| self.synthObj.setArgs(\in, v.value) }),
				\mod_in ->
				NumberBox(v, self.elementStyle.smallBoxSize)
					.action_({|v| self.synthObj.setArgs(\mod_in, v.value) }),
				\out ->
				NumberBox(v, self.elementStyle.smallBoxSize)
					.action_({|v| self.synthObj.setArgs(\out, v.value) })
			]);
		}, 44@82);
	});

	self.elementDictionary.put(
		\depth,
		EZKnob.new(w, self.elementStyle.knobSize, 'depth', \amp,
			action: {|v|
				self.synthObj.setArgs(\depth, v.value);
				self.updateMIDI(\depth, v.value);
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
			ToggleButton(v, " B ", {
				self.synthObj.runSynth(false);
				self.bpObj=Synth.after(self.synthObj.synthObj, \bp_1,
					[\in, self.synthObj.synthArgDictionary.at(\in),
						\out, self.synthObj.synthArgDictionary.at(\out)
					]
				);
			}, {
				self.synthObj.runSynth(true);
				(self.bpObj.notNil).if({ self.bpObj.free });
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

~distort2Gui.valueDictionary=Dictionary[
	\disttype -> 0,
	\in-> 38,
	\mod_in -> 39,
	\out -> 0,
	\depth -> 1,
	\mute -> 0,
	\play -> 1
];

// MIDI
~distort2Midi = ~incDecMidi.reproduce;
~distort2Midi.synthObj=~distort2Synth;
~distort2Midi.guiObj=~distort2Gui;
~distort2Midi.valueDictionary=~distort2Gui.valueDictionary.copy;
~distort2Midi.makeResponder={|self|
	self.responderObj=IncDecResponderBank(
		self.src,
		self.chan,
		self.ccDictionary.at(\depth), 0.0078, \amp,
			{|s, c, n, v|
				self.synthObj.setArgs(\depth, v);
				self.updateGui(\depth, v, \valueNoAction_);
			},
			self.valueDictionary.at(\depth)
	);
	self.responderObj;
};

~distort2Instr=(
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
	theSynth: ~distort2,
	theGui: ~distort2Gui,
	theMidi: ~distort2Midi,
	midiOn: {|self|
		self.theGui.midiObj=self.theMidi;
	}
)
)