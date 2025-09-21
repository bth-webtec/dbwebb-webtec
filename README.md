# @dbwebb/webtec CLI 

A cli to work with the course webtec, for students and staff.



## Install

You can install the tool through npm as this.

```bash
npm i @dbwebb/webtec --save-dev
```



### Update

You can update to the latest version like this.

```bash
npm update @dbwebb/webtec@latest
```



## Execute the `check` command

You can execute the command like this and the result is a helptext on how to use the command.

```bash
npx @dbwebb/webtec check <kmom>
```

The following commands are supported.

```bash
npx @dbwebb/webtec check labbmiljo
npx @dbwebb/webtec check kmom01
npx @dbwebb/webtec check kmom02
npx @dbwebb/webtec check kmom03
```

When you run kmom01, it will also check labbmiljo.

When you run kmom02, it will also check kmom01 and labbmiljo (and so on).

You can get a helptext like this.

```bash
npx @dbwebb/webtec check --help
```


### Execute subcommand `check lab`

This command prints out the summary row from a lab and visualises the points on each lab. This is used to show a summary of the points of several labs.

You can use it like this to show the results from one lab.

```
# Show the result from one lab
npx @dbwebb/webtec check lab lab_01
```

You can use it like this to show the results from several labs.

```
# Show the result from one lab
npx @dbwebb/webtec check lab lab_01 lab_02
```



## To be done

These will be supported but are yet not implemented.

```bash
npx @dbwebb/webtec check kmom04
npx @dbwebb/webtec check kmom05
npx @dbwebb/webtec check kmom06
npx @dbwebb/webtec check kmom10
```




<!--
## Developer

Use `npm link` to make a local link to the scripts. Then run like this.

```bash
check-files
help
```
-->