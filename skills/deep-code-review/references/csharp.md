# C# failure-mode pack

C#-specific high-frequency failure modes feeding deep-code-review.

## Error swallowing
- Empty `catch {}` / `catch (Exception) {}` / `catch { return null; }` — cause lost, callers proceed on false premises. Log-and-forget (log then continue, cause unaddressed) counts too.

## Async blocking (deadlocks)
- `.Result` / `.Wait()` / `.GetAwaiter().GetResult()` on a UI/ASP.NET sync context deadlocks.
- Spread: same pattern in other handlers / property getters? Root: can the whole call chain go async/await?
- `async void` (outside event handlers) — exceptions uncatchable, callers can't await.

## Resource disposal (IDisposable / missing using)
- `IDisposable` dropped without `using`/`await using` (Stream/SqlConnection misuse; new `HttpClient` per call).
- Field-held disposables not released in the class's `Dispose`.

## Event unsubscription leaks
- `+=` without `-=` (long-lived subscribing to short-lived → leak).
- Strong references where WeakEvent is needed.

## WPF / ReactiveUI lifecycle
- ViewModel teardown missing `CompositeDisposable`/`DisposeWith` / event handler / `Subscribe` disposal.
- Do `ObservableAsPropertyHelper`/`WhenAnyValue` subscriptions end with VM disposal?

## Nullable reference types / null design
- Frequent `!` (null-forgiving) under `#nullable enable` = the design failed to eliminate null.
- Before adding guards: can initialization order / constructors / contracts make null impossible?

## Other easily spread patterns
- Mixed `DateTime.Now` (`UtcNow`/timezones), `==` string comparison (culture), unparameterized SQL.
