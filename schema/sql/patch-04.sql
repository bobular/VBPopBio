ALTER TABLE ONLY nd_experiment_stock ADD CONSTRAINT nd_experiment_stock_c1 UNIQUE (nd_experiment_id, stock_id);
CREATE INDEX nd_experiment_stock_idx1 ON nd_experiment_stock USING btree (stock_id);
CREATE INDEX nd_experiment_stock_idx2 ON nd_experiment_stock USING btree (nd_experiment_id);
