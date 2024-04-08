#!/usr/bin/env bash
BASEDIR=$(dirname "$0")

fly login -t main -c https://concourse.sre.pea-mgmt.nbcuni.com -n main
fly set-pipeline -t main -c "${BASEDIR}/../ci/pipeline.yaml" -p tf-databricks
