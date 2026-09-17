# Stack detection hints (multi-language)

Detection tables for identifying languages, frameworks, entry points, DB, and config, with code as the single source of truth. **Exploration via Grep/Glob/Read only.**

## 1. Manifests → ecosystem

Find manifests with `Glob` first to pin the ecosystem.

| Manifest (Glob pattern) | Ecosystem | What to read |
|---|---|---|
| `**/*.sln`, `**/*.csproj`, `**/*.vbproj` | .NET (C#/VB.NET) | TargetFramework, PackageReference, OutputType |
| `**/*.vbp`, `**/*.vbg` | VB6 | references (Reference/Object), Startup, Form/Module list |
| `**/package.json` | Node/JS/TS | scripts, dependencies, main/exports, type |
| `**/pyproject.toml`, `**/requirements*.txt`, `**/setup.py`, `**/Pipfile` | Python | deps, entry_points, `[project.scripts]` |
| `**/go.mod` | Go | module name, require |
| `**/pom.xml`, `**/build.gradle*` | Java/Kotlin/JVM | dependencies, mainClass |
| `**/Cargo.toml` | Rust | dependencies, `[[bin]]` |
| `**/composer.json` | PHP | require, autoload, scripts |
| `**/Gemfile`, `**/*.gemspec` | Ruby | gems, executables |
| `**/*.ps1`, `**/*.psm1`, `**/*.psd1` | PowerShell | Export-ModuleMember, RootModule, FunctionsToExport |
| `**/*.vbs` | VBScript | entry = top-level statements (no Main equivalent) |

Multiple hits (e.g. TS frontend + C# backend) → treat as monorepo/multi-tier, assigning each to its own area.

## 2. Extensions → language (estimate the primary by distribution)

`.cs`=C# / `.vb`=VB.NET / `.bas`/`.frm`/`.cls`/`.ctl`=VB6 / `.vbs`=VBScript / `.ps1`/`.psm1`/`.psd1`=PowerShell / `.py`=Python / `.ts`/`.tsx`/`.js`/`.jsx`=JS/TS / `.go`=Go / `.java`=Java / `.kt`=Kotlin / `.rs`=Rust / `.php`=PHP / `.rb`=Ruby / `.sql`=SQL / `.sh`=Shell.

## 3. Entry-point detection

| Language/FW | How to find (Grep) |
|---|---|
| C# console/general | `static.*Main\s*\(`, `Program.cs`, `[Ss]ub Main` |
| ASP.NET | `Program.cs`/`Startup.cs`, `MapControllers`, `app.Map`, `[ApiController]`, `.aspx`, `Global.asax` |
| VB6 | `Startup=` in the `.vbp`, form `Sub Main`, `Form_Load` |
| VBScript | top-level executable statements / `WScript.Arguments` |
| PowerShell | `RootModule`/`FunctionsToExport` in `.psd1`, leading `param(...)` |
| Python | `if __name__ == .__main__.`, `[project.scripts]`, `manage.py` (Django), `main.py`/`app.py`, `@app.route`/`FastAPI(` |
| Node/TS | package.json `main`/`bin`/`scripts.start`, `index.ts`, `server.ts`; Next.js: `app/`/`pages/` |
| Go | `func main\s*\(`, `package main` |
| Java/Kotlin | `public static void main`, `@SpringBootApplication` |

## 4. Layer/responsibility clues (directories, naming)

- UI/presentation: `ui`, `views`, `pages`, `components`, `forms`, `.frm`, `.aspx`, `.xaml`, `templates`
- App/services: `services`, `handlers`, `controllers`, `usecases`, `application`
- Domain: `domain`, `models`, `entities`, `core`
- Data: `repositories`, `dao`, `data`, `db`, `persistence`, `migrations`
- Integrations: `integrations`, `clients`, `api`, `gateways`, `adapters`
- Jobs/daemons: `jobs`, `workers`, `tasks`, `schedulers`, `daemons`, Windows Service

## 5. Data models / DB schema

| Clue (Grep) | Meaning |
|---|---|
| `DbContext`, `[Table(`, `EntityTypeConfiguration`, `.edmx` | EF / EF Core |
| `class .*\(.*Base.*\)` + `Column(`, `sqlalchemy` | SQLAlchemy |
| `schema.prisma` | Prisma |
| `CREATE TABLE`, `**/*.sql`, `migrations/**` | raw SQL / migrations |
| `ADODB`, `rs.Open`, `cmd.CommandText` | classic ADO (VB6/VBS/ASP) |
| `models.Model` (Django), `@Entity` (JPA) | ORM models |

## 6. Config / env vars / secrets

`Glob`: `.env.example`, `.env*`, `appsettings*.json`, `App.config`, `web.config`, `*.ini`, `*.toml`, `config/**`, `settings*.py`.
- List env-var **key names only — never transcribe values or secrets.**
- Reading `.env` (real values) is allowed, but never write values into docs; document keys + purpose from `.env.example` only.

## 7. Feeding the output

Detection results feed each CODEMAP's entry points, module tables, external deps, and data flow. Leave undetected/ambiguous items as 「未確認」; never fill with guesses.
