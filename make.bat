@rem Assembles and links BFTRANS using Microsoft Macro Assembler.
ml      /c /Zi /Fl bftrans.asm
ml      /c /Zi /Fl bfio.asm
link    /CO bftrans.obj bfio.obj,bftrans.exe,nul.map,,nul.def
