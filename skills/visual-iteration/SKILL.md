---
name: visual-iteration
description: How to make visual and layout changes without burning rounds. Use when changing CSS, layout, spacing, or anything the user judges by looking at it. Prevents the guess-render-guess loop that turns a one-sentence request into five exchanges.
---

# Visual changes: stop guessing

Layout work has a failure mode all its own. The request is one sentence — "make it a bit bigger",
"move it left", "it's cut off" — and the fix is five rounds of adjusting numbers and asking whether
that's better. Each round costs the other person a look, and they can feel the guessing.

## The two-attempt rule

**If two attempts have not fixed a visual bug, stop changing values and find the actual cause.**

The third guess is almost never right, because by then the problem is not the value you keep
adjusting. Real examples, each of which survived several rounds of guessing:

- A modal's title rendered outside its box. Read as a flexbox problem. It was a **global
  `header { }` rule** applying to a portaled `<header>` element.
- A scroll effect that "could not be happening given the source" — the old listener was still alive
  from a hot reload. The source was fine.

**Grep for global element selectors** (`header`, `main`, `section`, `ul`) before assuming the
component you are looking at owns its own layout. And in portals, prefer a `div` with a class over a
semantic tag that global CSS may claim.

## Diagnose from the rendered page, not the stylesheet

Read the *computed* style of the real element. Which rule won, what the box actually measures, what
the parent's constraints are. A stylesheet tells you what was declared; only the page tells you what
applied.

## Their browser is not your browser

If you have a preview pane, it is not what they are looking at. Different engine, different fonts,
different locale, different zoom. "It looks fine here" is not evidence about their screen.

Two habits that follow:

- Check the thing that differs — engine-specific behaviour, dark mode, the narrow breakpoint — rather
  than confirming it works in the one place you can see.
- **Ask for a screenshot when the description is ambiguous.** "Grow it slightly" has a wide range;
  an annotated image has one. This is not an admission of failure; it converts three rounds into one.

## Change one thing

When several properties could plausibly be at fault, changing three at once means the next round
teaches you nothing. Change one, look, keep or revert. Slower per step, far faster to done.

## Know when the answer is "don't"

Some surfaces should not be adapted — a dense table on a phone is worse as a squeezed table than as
a summary with a link, or simply excluded. **"This doesn't belong here" is a legitimate design
answer**, provided it is stated rather than quietly shipped.
