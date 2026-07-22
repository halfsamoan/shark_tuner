# SharkTune agent roles

Use only one writer for a Flutter change. The root agent owns the design
contract and final acceptance; each review role is read-only and returns
evidence, not patches. These project-local roles intentionally adapt the
selected role names from VoltAgent's public agent catalogue to the toauner
architecture and AGENTS.md contract.

| Role | Authority | Required handoff |
| --- | --- | --- |
| `ui-designer` | Read-only | Player task, focal point, hierarchy, subtraction, state table, Figma notes. |
| `flutter-expert` | Sole Flutter code writer | Focused failing test, implementation, formatter/analyzer/golden evidence. |
| `accessibility-tester` | Read-only | TalkBack, contrast, 48dp, text scale, grayscale, reduced-motion findings. |
| `performance-engineer` | Read-only | Live-render, audio-isolate, battery, jank, interruption findings. |

Do not give a review role credentials, production publishing access, or an
unbounded refactor. Return every finding to `flutter-expert`; do not allow two
agents to edit the same Flutter file.
