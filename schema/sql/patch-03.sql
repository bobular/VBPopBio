ALTER TABLE ONLY nd_experiment_project ADD CONSTRAINT nd_experiment_project_c1 UNIQUE (nd_experiment_id, project_id);
CREATE INDEX nd_experiment_project_idx1 ON nd_experiment_project USING btree (project_id);
CREATE INDEX nd_experiment_project_idx2 ON nd_experiment_project USING btree (nd_experiment_id);
