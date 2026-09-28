# LogDrop Taint — Flutter

Taint (data-flow) analysis for Dart and Flutter source, as a GitHub Action.

**Your source never leaves the runner.** The analyzer reads your code on the machine
that checked it out and writes a SARIF report. Nothing is uploaded unless you ask for
it, and what can be uploaded is the report — never the code.

```yaml
- uses: actions/checkout@v4
- uses: initialcodess/logdrop-taint-flutter-action@<commit-sha>
  with:
    license: ${{ secrets.LOGDROP_LICENSE }}
```

That is the whole minimum. Findings appear inline on the pull request and in the job
summary, and the build stays green — see **The scan is advisory** below.

## What it finds

| rule | what it reports |
|---|---|
| `FL-TAINT-CLIPBOARD` | a recovery key, a TOTP seed or a card number copied to the system clipboard |
| `FL-TAINT-CREDENTIALS-LOCAL-STORE` | a token or a PIN written to unencrypted `SharedPreferences` |
| `FL-TAINT-PII-LOG` | a credential reaching a log line, including inside a `${...}` interpolation |

Measured on nine real Flutter applications before any of them was written: **12 findings,
zero false positives**, every one read in source. The acceptance records live in the
analyzer repository.

## Pin by commit SHA, not `@v1`

```yaml
uses: initialcodess/logdrop-taint-flutter-action@a1b2c3d4...
```

This action runs inside your CI with your source checked out. A moving tag means its
owner decides what executes there, whenever they like. A SHA means you decide.

It also pins the checksum the installer verifies the analyzer against — that table lives
*inside this action*, not beside the download, precisely so that replacing a release is
not enough to change what runs on your machine.

## The scan is advisory

`fail-on` defaults to `never`: findings are reported and the build stays green. A
scanner that breaks someone's pipeline on its own judgement gets removed from the
pipeline.

```yaml
with:
  license: ${{ secrets.LOGDROP_LICENSE }}
  fail-on: high      # critical | high | medium | low | never
```

## No source in the report, ever

Most analyzers put the offending line into the SARIF. This one does not: a finding is a
rule, a file and a line. There is no flag to turn it on, because there is no reason a
report needs to carry your code.

## Sending reports to the LogDrop panel

Set `panel-url` and `bundle-id`. Only the SARIF is sent.

```yaml
with:
  license: ${{ secrets.LOGDROP_LICENSE }}
  panel-url: https://analyze.logdrop.io
  bundle-id: com.company.app
```

A panel that is down, a licence moved between projects, or a bundle id deleted in the
panel will warn rather than fail your build — none of them is something the developer
who opened the pull request can fix. Set `fail-on-delivery-error: true` if you would
rather know loudly.

## Requirements

Nothing. The analyzer is one self-contained binary: no Flutter SDK, no Dart SDK, no
`pub get`, and none of your dependencies. Published for `linux-x64` and `macos-arm64`.

## Exit codes

| code | meaning |
|---|---|
| 0 | clean |
| 1 | findings at or above `fail-on` |
| 2 | licence failure |
| 3 | bad arguments |
| 4 | the scan could not complete |

They are kept distinct on purpose: a developer whose licence lapsed must never be told
their code has a vulnerability.

---

© Initial Code Software Solutions. Questions: destek@initialcode.io
