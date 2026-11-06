import autoAnimate, { getTransitionSizes } from "@formkit/auto-animate"

const duration = 250
const easing = "ease-in-out"

function animation(el, action, oldCoords, newCoords) {
  const animationDuration = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    ? 0
    : duration
  let keyframes

  if (action === "add") {
    keyframes = [{ opacity: 0 }, { opacity: 1 }]
  }

  if (action === "remove") {
    keyframes = [{ opacity: 1 }, { opacity: 0 }]
  }

  if (action === "remain") {
    const deltaX = oldCoords.left - newCoords.left
    const deltaY = oldCoords.top - newCoords.top
    const [widthFrom, widthTo, heightFrom, heightTo] = getTransitionSizes(
      el,
      oldCoords,
      newCoords,
    )
    const start = { transform: `translate(${deltaX}px, ${deltaY}px)` }
    const end = { transform: "translate(0, 0)" }

    if (widthFrom !== widthTo) {
      start.width = `${widthFrom}px`
      end.width = `${widthTo}px`
    }

    if (heightFrom !== heightTo) {
      start.height = `${heightFrom}px`
      end.height = `${heightTo}px`
    }

    keyframes = [start, end]
  }

  return new KeyframeEffect(el, keyframes, {
    duration: animationDuration,
    easing,
  })
}

export const AutoAnimate = {
  mounted() {
    this.animation = autoAnimate(this.el, animation)
  },

  destroyed() {
    this.animation.disable()
  },
}
