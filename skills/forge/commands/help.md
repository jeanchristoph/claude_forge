# Aide

**Déclencheur :** `/forge help` (« Branche de travail » de `SKILL.md`).

**Réaction :** afficher l'aide ci-dessous, traduite dans la langue de l'utilisateur, commandes comprises (`grave` en français, `engrave` en anglais). Aucune lecture de `.forge/`, aucun script, aucune question. STOP — ne pas continuer.

```
forge — one branch, one cycle

Cycle
  /forge                 resume the current branch, or start a new task from main/master
  /forge <goal>          new branch from the default branch, goal pre-filled
  /forge <branch>        switch to <branch> and resume it
  Brief → Plan → Active  goal validated, plan validated, tasks run and checked off

While working (plain words, no slash)
  engrave [dev master]   commit and push the branch, then merge it into the listed branches
  "done" / "end"         close the task: report, client reply
  "launch the swarm"     run the plan's child branches in parallel
  "launch an agent on branch X" / "do T3 in ../other-project"   delegate
  "rename the branch to X"
  "clean the forge"      review .forge/project.md
  "update the forge"     check for a new forge version and install it

Files — .forge/
  project.md, coding-standards.md     shared by every branch
  branch/<branch>/brief.md, plan.md, log.md
  branch/<branch>/output/             every generated file (reports, SQL, emails)
  input/, branch/<branch>/input/      reference files you bring
```
