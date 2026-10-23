import autoAnimate from "@formkit/auto-animate"

export const AutoAnimate = {
  mounted() {
    this.animation = autoAnimate(this.el, {
      duration: 250,
      easing: "ease-in-out",
    })
  },

  destroyed() {
    this.animation.disable()
  },
}
