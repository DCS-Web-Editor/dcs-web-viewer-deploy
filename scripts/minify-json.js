import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

//this is the target path of my json files, copyed from `./public/` by Vite
const publicDir = path.resolve(process.cwd());

//recursively call jsonminify to json files in directory
const minifyJsonFiles = (dir) => {
  fs.readdirSync(dir).forEach((file) => {
    const filePath = path.join(dir, file);

    const stat = fs.statSync(filePath);

    if (stat.isDirectory()) {
      // console.log("directory", filePath);
      minifyJsonFiles(filePath);
    } else if (path.extname(file) === ".json") {
      console.log(`Minifying: ${filePath}`);
      const content = fs.readFileSync(filePath, "utf8");
      const minifiedContent = JSON.stringify(JSON.parse(content));
      fs.writeFileSync(filePath, minifiedContent);
      console.log("OK");
    }
  });
};

minifyJsonFiles(publicDir);
