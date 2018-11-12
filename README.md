# tulipp-guidelines

This git repo is intentionally empty, but have a look at the wiki:

### [TULIPP Guidelines Wiki](https://github.com/tulipp-eu/tulipp-guidelines/wiki)

## Convert Guidelines in TeX format

1. Clone this repository  
`git clone https://github.com/tulipp-eu/tulipp-guidelines.git`
2. Clone the Wiki repository  
`git clone https://github.com/tulipp-eu/tulipp-guidelines.wiki.git`
3. Copy over the script  
`cp tulipp-guidelines/guideline2tex.sh tulipp-guidelines.wiki/`
4. Start converting  
`tulipp-guidelines.wiki/guideline2tex.sh`
5. Open and compile `tulipp-guidelines.wiki/master.tex`

### Remarks
 * This script has some requirements such as `pandoc`, missing requirements will be reported
 * Out of the box it will only convert referenced guidelines from the Wiki start page, open the script and change the 'includeUnreferenced' variable to include all markdown files.
 * This script does some postprocessing on the generated latex files such as  
    * Creating a section to each guideline
    * Putting a label for the guideline name and guideline number in it
    * limits images to \linewidth
    * uses tabularx for tables
    * uses hyperref for references between guidelines
 * The result is not perfect and needs some crafting afterwards, but it provides a good start
