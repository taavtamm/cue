# Known limits

Things Cue does on purpose, or can't do, so they don't surprise anyone on stage.

## Keeping screens in step

Every screen runs its own copy of the deck in its own web view. Cue keeps
them in step by sending each one the same position (slide and build), not by
copying pixels. A slide change reaches every screen within a frame or two.

Time-based animations need more than the position, because each page starts
an animation whenever it happened to load or show the slide. After each slide
change (about 0.45 s later, once the transition has run), Cue reads the
stage's animation clock — the current time of every animation on the shown
slide — and sets the same times on mirrors and the presenter's current slide.
A screen that joins mid-slide is lined up the same way once it's ready.
Turn this off in Displays ("Keep animations in sync across screens").

What still drifts:

- **Web embeds.** Live embeds run in sandboxed, cross-origin iframes. Cue
  can't reach their animations, so each screen's embed keeps its own timing
  from when it loaded, typically tens of milliseconds apart.
- **Scripted animation.** Content that animates from its own
  `requestAnimationFrame` loop or timers isn't a Web Animation and isn't
  aligned.
- **Between slide changes.** Alignment happens once per slide change. Screens
  with different refresh rates (60 Hz projector, 120 Hz laptop) step frames
  at different moments, so a frame of difference can appear and disappear.
- **Different states.** If the stage and a mirror have a different number of
  animations on the slide (for example one is still loading an embed),
  alignment is skipped for that slide rather than guessed.

## Screens plugged in or removed mid-show

The show never stops. When a screen disappears its window closes and the
others carry on. If it was the stage, a mirror becomes the stage; with no
mirror left, the presenter view keeps running and the audience screen comes
back when you give a screen the Stage role in Displays. A screen that is
plugged in mid-show gets the role it had last time in this set of screens, or
Off. A screen whose role changes gets a fresh window, so its page reloads
(about a second for a large deck).

## Presenter view

- The slide strip shows each slide's number and title, not a picture. A live
  thumbnail would need a web view per slide, and Cue never shows screenshots
  in place of the real deck.
- Pausing live content pauses Web Animations and media. Embeds and scripts
  with their own animation loops keep running.

## Display identity

Screens are recognised by the UUID macOS gives each display, so roles survive
reconnecting. Two identical monitors on the same ports can swap identity on
some docks; check Displays if roles look swapped.
