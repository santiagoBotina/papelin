# ADR-0006: Devise + Pundit for Authentication and Authorization

**Date:** 2026-06-02
**Status:** Accepted
**Deciders:** Engineering team

## Context

Papelin is an internal application. Users are company employees. The security model is role-based: employees see their own data (conversations, certificate requests), admins manage the system (upload documents, manage users). Self-registration should be disabled — admins create accounts.

## Decision

Use Devise for authentication (email/password) and Pundit for authorization (policy objects per resource). Devise modules: `database_authenticatable`, `registerable`, `recoverable`, `rememberable`, `validatable`.

## Options considered

| Option | Pros | Cons |
|--------|------|------|
| **Devise + Pundit** (chosen) | Mature, well-documented, standard Rails ecosystem; Pundit policies are plain Ruby objects — easy to unit test | Devise can be "magical" for newcomers; Pundit requires explicit `authorize` calls in every action |
| Rodauth + Pundit | More secure defaults; rack-based (framework-agnostic); excellent session security | Less Rails-idiomatic; steeper learning curve; fewer community examples for common use cases |
| Devise + CanCanCan | Devise integration is smooth; Ability class centralizes all rules | CanCanCan is less actively maintained; `can?` checks can become a god-class; harder to test individual permissions |
| Devise + Action Policy | Same philosophy as Pundit but with more features (policy classes, lazy evaluation) | Newer gem; smaller community; Pundit's simplicity is preferred for this project's scope |
| Hand-rolled sessions + auth | Full control; no gem dependencies | Easy to get security wrong (timing attacks, session fixation); reinventing the wheel |

## Consequences

**Positive:**
- No OAuth / SSO in the initial implementation — Devise email/password is sufficient for an internal company app
- Pundit requires `authorize` to be called in every controller action — enforced via `after_action :verify_authorized`
- Policy objects are plain Ruby — easy to unit test in isolation
- Devise `:validatable` enforces password strength rules out of the box

**Negative / trade-offs:**
- Self-registration is disabled; admins must create user accounts manually (acceptable for internal tool)
- Devise adds several routes and views that must be customized for the company brand
- Adding SSO (Google Workspace, Azure AD) later would require significant rework of the authentication layer
- Devise's `registerable` module is included but must be restricted to prevent public registration

## References
- https://github.com/heartcombo/devise
- https://github.com/varvet/pundit
- https://www.rubydoc.info/gems/devise
