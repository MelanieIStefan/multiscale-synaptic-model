: $Id: netstim.mod,v 1.6 2006/04/10 21:14:23 hines Exp $
: comments at end

: Stimulator to provide sinusoidally modulated spike frequency.
:   Adapted from netstim.hoc
:   BPG 16-11-07

NEURON	{ 
  ARTIFICIAL_CELL SinStim
  RANGE start, end, mstart, mend, meanfr, dfr, sinfr
  RANGE noise
  POINTER donotuse
}

UNITS {
	(nA) = (nanoamp)
	(mV) = (millivolt)
	(uS) = (microsiemens)
	PI = (pi) (1)
}

PARAMETER {
	start		= 50 (ms)	: start of first spike
	end		= 500 (ms)	: end of spikes
	mstart		= 50 (ms)	: start of sinusoidal modulation
	mend		= 500 (ms)	: end of sinusoidal modulation
	meanfr=50 (Hz)	: mean frequency of spikes per synapse
	dfr=20	(Hz)	: frequency modulation (+-mean)
	sinfr=2 (Hz)		: modulation frequency
	noise		= 0 <0,1>	: amount of randomness (0.0 - 1.0)
}

ASSIGNED {
	freq (Hz)
	interval (ms)
	event (ms)
	on
	ispike
	donotuse
}

PROCEDURE seed(x) {
	set_seed(x)
}

INITIAL {
	on = -1 : tenatively off
	ispike = 0
	interval = 1000/meanfr	: ISI (msecs)
	if (noise < 0) {
		noise = 0
	}
	if (noise > 1) {
		noise = 1
	}
	if (start >= 0) {
		: randomize the first spike so on average it occurs at
		: start + noise*interval
		event = start + invl(interval) - interval*(1. - noise)
		: but not earlier than 0
		if (event < 0) {
			event = 0
		}
		net_send(event, 3)
	}
}	

PROCEDURE init_sequence(t(ms)) {
		on = 1
		event = 0
		ispike = 0
}

FUNCTION invl(mean (ms)) (ms) {
	if (mean <= 0.) {
		mean = .01 (ms) : I would worry if it were 0.
	}
	if (noise == 0) {
		invl = mean
	}else{
		invl = (1. - noise)*mean + noise*mean*erand()
	}
}
VERBATIM
double nrn_random_pick(void* r);
void* nrn_random_arg(int argpos);
ENDVERBATIM

FUNCTION erand() {
VERBATIM
	if (_p_donotuse) {
		/*
		:Supports separate independent but reproducible streams for
		: each instance. However, the corresponding hoc Random
		: distribution MUST be set to Random.negexp(1)
		*/
		_lerand = nrn_random_pick(_p_donotuse);
	}else{
ENDVERBATIM
		: the old standby. Cannot use if reproducible parallel sim
		: independent of nhost or which host this instance is on
		: is desired, since each instance on this cpu draws from
		: the same stream
		erand = exprand(1)
VERBATIM
	}
ENDVERBATIM
}

PROCEDURE noiseFromRandom() {
VERBATIM
 {
	void** pv = (void**)(&_p_donotuse);
	if (ifarg(1)) {
		*pv = nrn_random_arg(1);
	}else{
		*pv = (void*)0;
	}
 }
ENDVERBATIM
}

PROCEDURE next_invl() {
	freq = meanfr
	if (t > mstart && t < mend) {	: modulate frequency
	  freq = meanfr + dfr*sin((sinfr*2*PI/1000)*(t-mstart))

	}
	interval = 1000/freq
	if (t < end) {
		event = invl(interval)
	} else {
		on = 0
	}
}

NET_RECEIVE (w) {
	if (flag == 0) { : external event
		if (w > 0 && on == 0) { : turn on spike sequence
			: but not if a netsend is on the queue
			init_sequence(t)
			: randomize the first spike so on average it occurs at
			: noise*interval (most likely interval is always 0)
			next_invl()
			event = event - interval*(1. - noise)
			net_send(event, 1)
		}else if (w < 0) { : turn off spiking definitively
			on = 0
		}
	}
	if (flag == 3) { : from INITIAL
		if (on == -1) { : but ignore if turned off by external event
			init_sequence(t)
			net_send(0, 1)
		}
	}
	if (flag == 1 && on == 1) {
		ispike = ispike + 1
		net_event(t)
		next_invl()
		if (on == 1) {
			net_send(event, 1)
		}
	}
}

COMMENT
Presynaptic spike generator
---------------------------

This mechanism has been written to be able to use synapses in a single
neuron receiving various types of presynaptic trains.  This is a "fake"
presynaptic compartment containing a spike generator.  The trains
of spikes can be either periodic or noisy (Poisson-distributed)

Parameters;
   noise: 	between 0 (no noise-periodic) and 1 (fully noisy)
   interval: 	mean time between spikes (ms)
   number: 	number of spikes (independent of noise)

Written by Z. Mainen, modified by A. Destexhe, The Salk Institute

Modified by Michael Hines for use with CVode
The intrinsic bursting parameters have been removed since
generators can stimulate other generators to create complicated bursting
patterns with independent statistics (see below)

Modified by Michael Hines to use logical event style with NET_RECEIVE
This stimulator can also be triggered by an input event.
If the stimulator is in the on==0 state (no net_send events on queue)
 and receives a positive weight
event, then the stimulator changes to the on=1 state and goes through
its entire spike sequence before changing to the on=0 state. During
that time it ignores any positive weight events. If, in an on!=0 state,
the stimulator receives a negative weight event, the stimulator will
change to the on==0 state. In the on==0 state, it will ignore any ariving
net_send events. A change to the on==1 state immediately fires the first spike of
its sequence.

ENDCOMMENT
