# Finger Fate

A multi-touch finger chooser: a group places fingers on the screen and the app fairly picks one. This context covers the round lifecycle and its presentation.

## Language

### Round lifecycle

**Round**:
One complete chooser cycle, from the first finger down to lock-in or reset.
_Avoid_: game, session

**Candidate**:
An active finger eligible to win the current round.
_Avoid_: player, touch point

**Stability countdown**:
The wait (1.5s) after the touch set last changed before the roulette starts; any finger change restarts it.
_Avoid_: debounce, settle timer

**Roulette**:
The decelerating highlight sweep across candidates that lands on the winner.
_Avoid_: spin, shuffle, animation

**Hop**:
A single highlight step of the roulette, paired with a haptic that grows stronger as hops slow.
_Avoid_: tick, step

**Suspense hold**:
The beat after the final hop when the winner stays merely highlighted before lock-in.
_Avoid_: pause, delay

**Lock-in**:
The moment the winner is committed: heavy haptic, flower morph, banner.
_Avoid_: reveal, commit

**Winner / Loser**:
A candidate's fate after lock-in; losers recede, the winner becomes the hero.

### Presentation

**Blob**:
The filled palette-colored circle rendered under each candidate's finger.
_Avoid_: circle, dot, marker

**Hint pill**:
The serif capsule prompting for more fingers when fewer than two are down.
_Avoid_: toast, tooltip

**Winner banner**:
The serif "Fate has chosen" caption, tinted with the winner's color.
_Avoid_: overlay, label
