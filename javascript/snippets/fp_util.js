/**
 * For debugging pipe/compose
 * usage: 
 *   R.pipe(R.add(3), inspect("after-add"), R.multiply(5))(6); // [inspect] after-add: 9 
 */
export const inspect =
  (msg = "") =>
  (payload) => {
    console.log(`[inspect] ${msg}: `, payload);
    return payload;
  };

/**
 * For debugging a reducer
 * usage:
 *   sumFn = (acc, x) => acc + x;
 *   sum = array.reduce(inspectReducer(sumFn), 0);
 */
export const inspectReducer = (reducerFn) => (acc, x) => {
  console.log("acc: ", acc, ", x: ", x);
  const retval = reducerFn(acc, x);
  console.log("next: ", retval);
  return retval;
};
