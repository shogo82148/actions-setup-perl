import * as core from "@actions/core";
import * as cache from "@actions/cache";
import { State } from "./constants";

async function run() {
  try {
    const cachePath = core.getState(State.CachePath);
    const key = core.getState(State.CachePrimaryKey);
    const cachedKey = core.getState(State.CacheMatchedKey);
    const paths = [cachePath];
    // save cache
    if (cachedKey !== key) {
      core.info(`saving cache for ${key}.`);
      try {
        await cache.saveCache(paths, key);
      } catch (error) {
        if (error instanceof Error) {
          if (error.name === cache.ValidationError.name) {
            throw error;
          } else if (error.name === cache.ReserveCacheError.name) {
            core.info(error.message);
          } else {
            core.info(`[warning]${error.message}`);
          }
        } else {
          core.info(`[warning]${error}`);
        }
      }
    } else {
      core.info(`cache for ${key} already exists, skip saving.`);
    }
  } catch (error) {
    if (error instanceof Error) {
      core.setFailed(error);
    } else {
      core.setFailed(`${error}`);
    }
  }
}

run();
