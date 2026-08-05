---
name: design
summary: SOLID, DRY, SRP, coupling, abstraction quality, and code smells.
default: true
---

# Design lens

Judge the shape of the change: whether it will still be maintainable after three more people touch it. Design findings are real only when you can name the concrete future cost — otherwise they are taste, and taste does not belong in a review.

## Look for

**Single responsibility.** A unit that changes for more than one reason. The tell is the description: if you need "and" to describe what a function or module does, that is two things. Watch for functions that both decide and execute, and for classes that grow a new field per feature.

**Duplication that will drift.** Not every repetition is a defect — three lines repeated twice is usually cheaper than the abstraction. What matters is whether the copies must change *together*. Duplicated business rules, validation, and status catalogs drift silently and are the expensive kind.

**Open/closed.** Adding a case requires editing a switch in five files. Look for parallel conditionals keyed on the same enum scattered across modules — that is a missing polymorphic seam.

**Liskov and interface fit.** Subtypes that throw on inherited methods, or implementations that ignore half the interface. Interfaces so wide that every implementer stubs most of it.

**Dependency direction.** Concrete dependencies where the seam should be inverted; low-level modules imported by high-level policy; a domain layer that imports its transport or persistence.

**Coupling and cohesion.** Reaching through one object to get at another's internals. Modules that must be edited in lockstep. Shared mutable singletons used as a back channel.

**Smells worth naming.** Long parameter lists, boolean trap parameters, primitive obsession where a type would enforce a rule, temporal coupling (`init()` must precede `use()`), speculative generality built for a requirement nobody has stated, and dead code shipped "just in case."

## Do not flag

- Naming or formatting not written down in the repo's own instructions.
- Duplication whose copies genuinely evolve independently.
- Abstractions that are simple because the problem is simple. Demanding a pattern the problem does not have is a defect of the review, not the code.
- Refactors of untouched code. Scope is the change.

## Failure scenario requirement

State the maintenance cost concretely: what will have to be edited in more than one place, what breaks when the third case is added, which rule now lives in two files that can disagree.
