// Finding slides with content that moves on its own: embeds, video, audio,
// canvas, iframes, and CSS animations that loop forever. Drives the LIVE tag.

cue.findLiveSlides = (slides, known) => {
  const live = new Set(known);
  const looping = document.getAnimations()
    .filter((animation) => animation.effect && animation.effect.getTiming().iterations === Infinity)
    .map((animation) => animation.effect.target)
    .filter(Boolean);

  slides.forEach((slide, i) => {
    if (slide.querySelector('video, audio, canvas, iframe')) live.add(i);
    else if (looping.some((target) => slide.contains(target))) live.add(i);
  });
  return Array.from(live).sort((a, b) => a - b);
};
