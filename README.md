This repository contains 3 different pipeline that are made for jenkins- and their translatoion to a Tekton Pipeline. each translation is done using a different AI model, and is saved in a seperate folder.
Each pipeline consist of several steps, meant to test differetn functionality, and the model's ability to properly translate the Pipeline, and breake it into Tasks, Pipelines, and Pipelineruns.
Functionality tested in each pipeline:

Pipeline 1: Transfers and appends a message across pipeline stages.

Pipeline 2: Transforms a string based on user selection from a dropdown.

Pipeline 3: Extracts numbers from a string, calculates their sum, and formats the output.


Each folder contains the original jenkinsfile (under folder witht the pipeline's name) and the folder for the Tekton Conversion.
comparing the results from each model will be done by running sha-1 on each string resulted from the pipeline.
A shell script that runs the pipeline in a kind cluster and prints the log is called "run_pipeline.sh" and is under the main directory.
