#!/usr/bin/env bash
REPO_NAME=${1:-scale-ci-pipeline}
git clone https://github.com/innovation-sre/${REPO_NAME}
git remote add origin-rbc http://rbcgithub.fg.rbc.com/SFT0/${REPO_NAME}
git push origin-rbc master