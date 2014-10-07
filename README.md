![Icon](https://raw.github.com/dennisroche/Repave/master/icon.png)

Repave
==========

**NB:** This is **pre-pre-release**, still under <u>active development</u>. If you are interesting in using the script, please drop a message on [Twitter](https://twitter.com/dennisroche).

Repave is a PowerShell module that allows you to easily create a new Hyper-V Virtual Hard Disk (`*.vhdx`), apply Microsoft® Windows 8.0/8.1 and 10 image, and then configure that installation with a terse script using additional `Repave.*` modules and [OneGet](https://github.com/OneGet/).

With this Hyper-V VHD, you then have the option to run it as Virtual Machine or boot it directly to run it on bare-metal (where only the hard drive will be virtualised).

The design of the module focusses on speed and idempotency allowing you create multiple machine configurations easily.

Possible usages include:

* Trial pre-release versions of Microsoft® Windows without needing a second computer or reinstalling.
* Have a fresh install *ready-to-go*. Great for development environments, e.g. as a consultant it is nice to have a fresh install to start an engagement for a client.

Inspired by the work of fellow [Readify](http://readify.net/) consultants [Rob Moore](https://twitter.com/robdmoore), [Matt Davies](https://twitter.com/mdaviesnet), [Tatham Oddie](https://twitter.com/tathamoddie), and [BoxStarter](http://boxstarter.org/) creator [Matt Wrock](https://twitter.com/mwrockx).


Installation
---------------

As pre-release, download the source. In the future, plan to publish on [PsGet](http://psget.net/).


Minimum example
---------------

To get started all you need is this in a `.ps1` file:

```powershell
#Repave
#Requires –Version 4
#Requires -RunAsAdministrator
[CmdletBinding()]
param()

Push-Location $PSScriptRoot
Import-Module .\Repave\Repave.psd1

$iso = ".\ISOs\en-gb_windows_8.1_professional_n_vl_with_update_x64_dvd_4050338.iso"
New-Gen2Vhd -Size 25GB | Write-WindowsIsoToVhd -Iso $iso | Invoke-Repave -InstallScript {
    Write-Host "It is repaving time"
}
```	

Roadmap
---------------

**Next**

* Implement support for OneGet
* Add modules to configure various settings in Windows
* Add examples of machine configurations
* Create Nuget package

**Future**

* Boot VHD configuration
* Add integration tests
* Publish module on PsGet
* Add support for Microsoft® Windows 7, i.e. non-UEFI based virtual machines
* VHD restart to complete package instalation

FAQ
---------------

**Q:** How is Repave different from other solutions?
> **A:** The focus is on creating Hyper-V machine configurations, not your current configuration. It is terse and repeatable. It also uses [OneGet](https://github.com/OneGet/) at the core, which is the new package management solution from Microsoft.

**Q:** What is wrong with Chocolately?
> **A:** Nothing, as long you can <u>trust the packages that you installing</u>. I personally have been burnt before by a package installing more than described. 

**Q:** What is so great about OneGet?
> **A:** It is a unified package manager that is shipping with Powershell v5. [Read a preview on TechNet](http://blogs.technet.com/b/windowsserver/archive/2014/04/03/windows-management-framework-v5-preview.aspx).


Icon
---------------

[Mosaic](http://thenounproject.com/term/mosaic/17953/) designed by [Juan Pablo Bravo](http://thenounproject.com/bravo/) from The Noun Project
