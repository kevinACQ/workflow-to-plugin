# {{KIT NAME}}: install guide

Export this page to PDF (any method: a "make PDF" skill, Google Docs > Download > PDF, or
your browser's Print > Save as PDF) and save it as client/{{KIT NAME}}-Install-Guide.pdf.
Keep this text file in the repo: the sweep reads it, and it can't read inside the PDF.

## What you need

- A computer (not a phone) with a web browser
- A paid Claude plan (claude.ai)
- The download links from {{YOUR COMPANY}}

## Install (about 10 minutes)

1. **Download.** Click each download link. Each one saves a .zip file to your Downloads
   folder. Don't unzip or open them.
2. **Turn on skills.** Go to claude.ai, then Settings, then Capabilities. If you don't see a
   Skills section, turn on "Code execution and file creation" first.
3. **Upload.** Click "Upload skill" and pick one .zip file. Repeat for each file.
4. **Test.** Open a new chat and say:
   - "{{TEST LINE FOR SKILL 1}}"
   - "{{TEST LINE FOR SKILL 2}}"

## If something goes wrong

- **Upload rejected:** the file was probably unzipped or re-zipped. Download it again from the
  link and upload the original.
- **No Skills section:** check that you're on a paid plan and that "Code execution and file
  creation" is on.
- **Still stuck:** contact {{SUPPORT CONTACT}}.

## Getting updates

The download links always point to the newest version. To update a skill, download it again
from the same link and upload it the same way. If Claude says the skill already exists,
remove the old one in Settings > Capabilities first, then upload the new file.
