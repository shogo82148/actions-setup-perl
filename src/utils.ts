export function parseBoolean(s: string): boolean {
  // YAML 1.0 compatible boolean values
  switch (s) {
    case "y":
    case "Y":
    case "yes":
    case "Yes":
    case "YES":
    case "true":
    case "True":
    case "TRUE":
      return true;
    case "n":
    case "N":
    case "no":
    case "No":
    case "NO":
    case "false":
    case "False":
    case "FALSE":
      return false;
  }
  throw `invalid boolean value: ${s}`;
}
