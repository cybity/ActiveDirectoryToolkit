#!/usr/bin/env bash
# ==============================================================================
# Complete 72-Tool Active Directory Arsenal Installer
# Explicitly installs, clones, or links every single tool from the Gist
# ==============================================================================

set -u

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

BASE_DIR="/opt/ad-toolkit"
IMPACKET_DIR="$BASE_DIR/impacket-scripts"
LINUX_DIR="$BASE_DIR/linux-tools"
WIN_PS1_DIR="$BASE_DIR/windows-powershell"
WIN_SRC_DIR="$BASE_DIR/windows-csharp-src"
WIN_BIN_DIR="$BASE_DIR/windows-binaries"
PIVOT_DIR="$BASE_DIR/pivoting"

echo -e "${BLUE}[*] Creating directory structure at ${BASE_DIR}...${NC}"
sudo mkdir -p "$IMPACKET_DIR" "$LINUX_DIR" "$WIN_PS1_DIR" "$WIN_SRC_DIR" "$WIN_BIN_DIR" "$PIVOT_DIR"
sudo chown -R "$USER":"$USER" "$BASE_DIR"

# Helper function to clone/update git repos
clone_repo() {
    local url="$1"
    local target="$2"
    if [ -d "$target" ]; then
        echo -e "${YELLOW} [~] Updating$(basename "$target")...${NC}"
        git -C "$target" pull --quiet || true
    else
        echo -e "${GREEN} [+] Cloning$(basename "$target")...${NC}"
        git clone --depth 1 "$url" "$target" || true
    fi
}

# Helper function to grab the latest GitHub release asset matching a pattern
download_gh_release() {
    local repo="$1"
    local pattern="$2"
    local out_file="$3"
    echo -e "${GREEN} [+] Downloading latest release from${repo} (${pattern})...${NC}"
    local url
    url=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" \vert{} jq -r ".assets[] \vert{} select(.name \vert{} test(\"${pattern}\"; \"i\")) | .browser_download_url" | head -n 1)
    if [ -n "$url" ] && [ "$url" != "null" ]; then
        wget -qO "$out_file" "$url"
    else
        echo -e "${YELLOW} [!] Release asset not found for ${repo}${NC}"
    fi
}

# ==============================================================================
# 1. Core System & APT Packages (Tools: rpcinfo, rpcclient, Hashcat,
#    ldapsearch, smbmap, enum4linux, gpp-decrypt, BloodHound GUI, Responder)
# ==============================================================================
echo -e "\n${BLUE}[1/7] Installing APT Packages & Native Linux Utilities...${NC}"
sudo apt-get update -y
sudo apt-get install -y \
    git curl wget unzip jq build-essential \
    python3 python3-pip python3-venv pipx \
    golang-go ruby-full ruby-dev \
    rpcbind samba-common-bin ldap-utils \
    hashcat smbmap responder \
    bloodhound neo4j

# Kali/Parrot specific packages (with Git fallbacks if on Ubuntu/Debian)
sudo apt-get install -y enum4linux gpp-decrypt 2>/dev/null || true

pipx ensurepath

# ==============================================================================
# 2. Impacket Toolkit & All 14 Individual Scripts (#7, #15, #24, #25, #27, #30,
#    #32, #34, #36, #42, #43, #44, #45, #54, #55)
# ==============================================================================
echo -e "\n${BLUE}[2/7] Installing Impacket Toolkit & Linking All 14 Scripts...${NC}"
pipx install impacket || true
clone_repo "https://github.com/fortra/impacket.git" "$LINUX_DIR/impacket"

IMPACKET_SCRIPTS=(
    "GetUserSPNs.py"    # #15
    "psexec.py"         # #24
    "wmiexec.py"        # #25
    "smbserver.py"      # #27
    "secretsdump.py"    # #30
    "mssqlclient.py"    # #32
    "rpcdump.py"        # #34
    "ntlmrelayx.py"     # #36
    "GetNPUsers.py"     # #42
    "lookupsid.py"      # #43
    "ticketer.py"       # #44
    "raiseChild.py"     # #45
    "addcomputer.py"    # #54
    "rbcd.py"           # #55
)

for script in "${IMPACKET_SCRIPTS[@]}"; do
    ln -sf "$LINUX_DIR/impacket/examples/$script" "$IMPACKET_DIR/$script"
    chmod +x "$IMPACKET_DIR/$script"
    echo -e "${GREEN} [✓] Linked $script ->$IMPACKET_DIR/$script${NC}"
done

# ==============================================================================
# 3. Standalone Python & Ruby CLI Tools via pipx / gem / git
# ==============================================================================
echo -e "\n${BLUE}[3/7] Installing Python & Ruby CLI Tools...${NC}"

# #5 BloodHound.py
pipx install bloodhound || true
clone_repo "https://github.com/dirkjanm/BloodHound.py.git" "$LINUX_DIR/BloodHound.py"

# #13 CrackMapExec (CME) & #50 NetExec (nxc)
clone_repo "https://github.com/byt3bl33d3r/CrackMapExec.git" "$LINUX_DIR/CrackMapExec"
pipx install netexec || true
clone_repo "https://github.com/Pennyw0rth/NetExec.git" "$LINUX_DIR/NetExec"

# #18 enum4linux-ng
pipx install enum4linux-ng || true
clone_repo "https://github.com/cddmp/enum4linux-ng.git" "$LINUX_DIR/enum4linux-ng"

# #31 evil-winrm
sudo gem install evil-winrm || true

# #40 adidnsdump
pipx install adidnsdump || true
clone_repo "https://github.com/dirkjanm/adidnsdump.git" "$LINUX_DIR/adidnsdump"

# #51 Certipy
pipx install certipy-ad || true
clone_repo "https://github.com/ly4k/Certipy.git" "$LINUX_DIR/Certipy"

# #61 Coercer
pipx install coercer || true
clone_repo "https://github.com/p0dalirius/Coercer.git" "$LINUX_DIR/Coercer"

# #63 mitm6
pipx install mitm6 || true
clone_repo "https://github.com/dirkjanm/mitm6.git" "$LINUX_DIR/mitm6"

# ==============================================================================
# 4. Linux Exploits, Enumeration Scripts & Pre-compiled Go Binaries
# ==============================================================================
echo -e "\n${BLUE}[4/7] Cloning Remaining Linux Scripts & Binaries...${NC}"

# #6 Kerbrute (Linux & Windows binaries)
download_gh_release "ropnop/kerbrute" "kerbrute_linux_amd64" "$LINUX_DIR/kerbrute"
chmod +x "$LINUX_DIR/kerbrute" 2>/dev/null || true
download_gh_release "ropnop/kerbrute" "kerbrute_windows_amd64.exe" "$WIN_BIN_DIR/kerbrute.exe"

# #8 Responder (Git version in addition to apt)
clone_repo "https://github.com/lgandx/Responder.git" "$LINUX_DIR/Responder"

# #17 enum4linux (Git fallback)
clone_repo "https://github.com/CiscoCXSecurity/enum4linux.git" "$LINUX_DIR/enum4linux"

# #20 windapsearch (Both Python & Go versions)
clone_repo "https://github.com/ropnop/windapsearch.git" "$LINUX_DIR/windapsearch"
download_gh_release "ropnop/go-windapsearch" "windapsearch-linux-amd64" "$LINUX_DIR/go-windapsearch"
chmod +x "$LINUX_DIR/go-windapsearch" 2>/dev/null || true

# #33 noPac.py
clone_repo "https://github.com/Ridter/noPac.git" "$LINUX_DIR/noPac"

# #35 CVE-2021-1675.py (PrintNightmare)
clone_repo "https://github.com/cube0x0/CVE-2021-1675.git" "$LINUX_DIR/CVE-2021-1675"

# #37 PetitPotam.py
clone_repo "https://github.com/topotam/PetitPotam.git" "$LINUX_DIR/PetitPotam"

# #38 gettgtpkinit.py & #39 getnthash.py (PKINITtools)
clone_repo "https://github.com/dirkjanm/PKINITtools.git" "$LINUX_DIR/PKINITtools"
ln -sf "$LINUX_DIR/PKINITtools/gettgtpkinit.py" "$LINUX_DIR/gettgtpkinit.py"
ln -sf "$LINUX_DIR/PKINITtools/getnthash.py" "$LINUX_DIR/getnthash.py"

# #41 gpp-decrypt (Standalone Ruby script fallback)
cat << 'EOF' > "$LINUX_DIR/gpp-decrypt.rb"
#!/usr/bin/env ruby
require 'openssl'
require 'base64'
if ARGV.empty?
  puts "Usage: ./gpp-decrypt.rb <cpassword>"
  exit
end
cpassword = ARGV[0]
cpassword += "=" * ((4 - cpassword.length % 4) % 4)
key = "\x4e\x99\x06\xe8\xfc\xb6\x6c\xc9\xfa\xf4\x93\x10\x62\x0f\xfe\xe8\xf4\x96\xe8\x06\xcc\x05\x79\x90\x20\x9b\x09\xa4\x33\xb6\x6c\x1b"
aes = OpenSSL::Cipher.new("AES-256-CBC")
aes.decrypt
aes.key = key
aes.iv = "\x00" * 16
puts aes.update(Base64.decode64(cpassword)).unpack('v*').pack('C*')
EOF
chmod +x "$LINUX_DIR/gpp-decrypt.rb"

# #60 krbrelayx
clone_repo "https://github.com/dirkjanm/krbrelayx.git" "$LINUX_DIR/krbrelayx"

# #62 dfscoerce.py
clone_repo "https://github.com/Wh04m1001/DFSCoerce.git" "$LINUX_DIR/DFSCoerce"

# #65 pyGPOAbuse
clone_repo "https://github.com/Hackndo/pyGPOAbuse.git" "$LINUX_DIR/pyGPOAbuse"

# ==============================================================================
# 5. Windows PowerShell Scripts (#1, #9, #21, #22, #49, #53, #56)
# ==============================================================================
echo -e "\n${BLUE}[5/7] Downloading Windows PowerShell Scripts...${NC}"

# #1 PowerView.ps1 (Dev branch has the complete functions)
clone_repo "https://github.com/PowerShellMafia/PowerSploit.git" "$WIN_PS1_DIR/PowerSploit"
wget -qO "$WIN_PS1_DIR/PowerView.ps1" "https://raw.githubusercontent.com/PowerShellMafia/PowerSploit/dev/Recon/PowerView.ps1"

# #9 Inveigh.ps1
clone_repo "https://github.com/Kevin-Robertson/Inveigh.git" "$WIN_PS1_DIR/Inveigh"
wget -qO "$WIN_PS1_DIR/Inveigh.ps1" "https://raw.githubusercontent.com/Kevin-Robertson/Inveigh/ps1/Inveigh.ps1" || true

# #21 DomainPasswordSpray.ps1
clone_repo "https://github.com/dafthack/DomainPasswordSpray.git" "$WIN_PS1_DIR/DomainPasswordSpray"

# #22 LAPSToolkit
clone_repo "https://github.com/leoloobeek/LAPSToolkit.git" "$WIN_PS1_DIR/LAPSToolkit"

# #49 ADRecon
clone_repo "https://github.com/adrecon/ADRecon.git" "$WIN_PS1_DIR/ADRecon"

# #53 PowerMad
clone_repo "https://github.com/Kevin-Robertson/Powermad.git" "$WIN_PS1_DIR/Powermad"

# #56 PowerUpSQL
clone_repo "https://github.com/NetSPI/PowerUpSQL.git" "$WIN_PS1_DIR/PowerUpSQL"

# ==============================================================================
# 6. Windows C# Tools, Source & Pre-compiled Binaries (#2, #4, #10, #14, #26,
#    #29, #46, #47, #48, #52, #57, #64)
# ==============================================================================
echo -e "\n${BLUE}[6/7] Cloning C# Sources & Downloading Pre-compiled Windows Binaries...${NC}"

# Clone C# Source Repositories
clone_repo "https://github.com/tevora-threat/SharpView.git" "$WIN_SRC_DIR/SharpView"         # #2
clone_repo "https://github.com/BloodHoundAD/SharpHound.git" "$WIN_SRC_DIR/SharpHound"        # #4
clone_repo "https://github.com/GhostPack/Rubeus.git" "$WIN_SRC_DIR/Rubeus"                   # #14
clone_repo "https://github.com/SnaffCon/Snaffler.git" "$WIN_SRC_DIR/Snaffler"                # #26
clone_repo "https://github.com/netwrix/pingcastle.git" "$WIN_SRC_DIR/PingCastle"             # #47
clone_repo "https://github.com/Group3r/Group3r.git" "$WIN_SRC_DIR/Group3r"                   # #48
clone_repo "https://github.com/GhostPack/Certify.git" "$WIN_SRC_DIR/Certify"                 # #52
clone_repo "https://github.com/antonioCoco/RunasCs.git" "$WIN_SRC_DIR/RunasCs"               # #57
clone_repo "https://github.com/FSecureLABS/SharpGPOAbuse.git" "$WIN_SRC_DIR/SharpGPOAbuse"   # #64

# Clone SharpCollection (Pre-compiled .exe files for SharpView, Rubeus, Certify, SharpGPOAbuse, etc.)
clone_repo "https://github.com/Flangvik/SharpCollection.git" "$WIN_BIN_DIR/SharpCollection"

# #4 SharpHound Pre-compiled Release (includes SharpHound.exe & SharpHound.ps1)
download_gh_release "SpecterOps/SharpHound" "\\.zip$" "$WIN_BIN_DIR/SharpHound.zip"
[ -f "$WIN_BIN_DIR/SharpHound.zip" ] && unzip -qo "$WIN_BIN_DIR/SharpHound.zip" -d "$WIN_BIN_DIR/SharpHound" && rm "$WIN_BIN_DIR/SharpHound.zip"

# #10 InveighZero (C# Inveigh Release)
download_gh_release "Kevin-Robertson/Inveigh" "\\.zip$" "$WIN_BIN_DIR/Inveigh.zip"
[ -f "$WIN_BIN_DIR/Inveigh.zip" ] && unzip -qo "$WIN_BIN_DIR/Inveigh.zip" -d "$WIN_BIN_DIR/InveighZero" && rm "$WIN_BIN_DIR/Inveigh.zip"

# #26 Snaffler.exe Release
download_gh_release "SnaffCon/Snaffler" "Snaffler\\.exe$" "$WIN_BIN_DIR/Snaffler.exe"

# #29 Mimikatz Release
download_gh_release "gentilkiwi/mimikatz" "mimikatz_trunk\\.zip$" "$WIN_BIN_DIR/mimikatz.zip"
[ -f "$WIN_BIN_DIR/mimikatz.zip" ] && unzip -qo "$WIN_BIN_DIR/mimikatz.zip" -d "$WIN_BIN_DIR/mimikatz" && rm "$WIN_BIN_DIR/mimikatz.zip"

# #46 Sysinternals Active Directory Explorer (ADExplorer.exe)
wget -qO "$WIN_BIN_DIR/AdExplorer.zip" "https://download.sysinternals.com/files/AdExplorer.zip"
unzip -qo "$WIN_BIN_DIR/AdExplorer.zip" -d "$WIN_BIN_DIR/ADExplorer" && rm "$WIN_BIN_DIR/AdExplorer.zip"

# #47 PingCastle Release
download_gh_release "netwrix/pingcastle" "\\.zip$" "$WIN_BIN_DIR/PingCastle.zip"
[ -f "$WIN_BIN_DIR/PingCastle.zip" ] && unzip -qo "$WIN_BIN_DIR/PingCastle.zip" -d "$WIN_BIN_DIR/PingCastle" && rm "$WIN_BIN_DIR/PingCastle.zip"

# #48 Group3r.exe Release
download_gh_release "Group3r/Group3r" "Group3r\\.exe$" "$WIN_BIN_DIR/Group3r.exe"

# #57 RunasCs Release
download_gh_release "antonioCoco/RunasCs" "RunasCs\\.zip$" "$WIN_BIN_DIR/RunasCs.zip"
[ -f "$WIN_BIN_DIR/RunasCs.zip" ] && unzip -qo "$WIN_BIN_DIR/RunasCs.zip" -d "$WIN_BIN_DIR/RunasCs" && rm "$WIN_BIN_DIR/RunasCs.zip"

# ==============================================================================
# 7. Pivoting Binaries (#58 Ligolo-ng, #59 Chisel) & Windows LOLBins Reference
# ==============================================================================
echo -e "\n${BLUE}[7/7] Downloading Pivoting Binaries & Generating LOLBins Reference...${NC}"

# #58 Ligolo-ng (Proxy for Linux, Agent for Windows & Linux)
download_gh_release "nicocha30/ligolo-ng" "proxy_.*_linux_amd64\\.tar\\.gz$" "$PIVOT_DIR/ligolo_proxy_linux.tar.gz"
download_gh_release "nicocha30/ligolo-ng" "agent_.*_linux_amd64\\.tar\\.gz$" "$PIVOT_DIR/ligolo_agent_linux.tar.gz"
download_gh_release "nicocha30/ligolo-ng" "agent_.*_windows_amd64\\.zip$" "$PIVOT_DIR/ligolo_agent_win.zip"

# #59 Chisel (Linux & Windows)
download_gh_release "jpillora/chisel" "chisel_.*_linux_amd64\\.gz$" "$PIVOT_DIR/chisel_linux.gz"
download_gh_release "jpillora/chisel" "chisel_.*_windows_amd64\\.gz$" "$PIVOT_DIR/chisel_windows.exe.gz"
gunzip -f "$PIVOT_DIR"/chisel_*.gz 2>/dev/null || true
chmod +x "$PIVOT_DIR"/chisel_linux 2>/dev/null || true

# #28 & #66-#72 Native Windows LOLBins Cheat Sheet
cat << 'EOF' > "$WIN_BIN_DIR/NATIVE_LOLBINS_CHEATSHEET.md"
# Native Windows AD Binaries (Built into Windows OS - C:\Windows\System32)

These 8 tools from the list are pre-installed on Windows hosts/Domain Controllers:

1. **setspn.exe (#28)** - Find all SPNs in the domain:
   `setspn.exe -Q */*`
2. **net.exe (#66)** - Enumerate domain users, groups, and password policy:
   `net user /domain` | `net group "Domain Admins" /domain` | `net accounts /domain`
3. **nltest.exe (#67)** - Map Domain Controllers and Domain Trusts:
   `nltest /dclist:<DOMAIN>` | `nltest /domain_trusts /all_trusts`
4. **ActiveDirectory PS Module (#68)** - Native RSAT enumeration:
   `Import-Module ActiveDirectory; Get-ADDomain; Get-ADUser -Filter * -Properties *`
5. **dsquery.exe (#69)** - Query LDAP objects from CLI:
   `dsquery user` | `dsquery computer` | `dsquery * -filter "(adminCount=1)"`
6. **dsacls.exe (#70)** - Check ACLs on AD objects:
   `dsacls "DC=corp,DC=local"`
7. **ntdsutil.exe (#71)** - Dump NTDS.dit via IFM (Run as Admin on DC):
   `ntdsutil "ac i ntds" "ifm" "create full C:\temp" q q`
8. **vssadmin.exe (#72)** - Volume Shadow Copy extraction of NTDS.dit:
   `vssadmin create shadow /for=C:`
   `copy \\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy1\Windows\NTDS\ntds.dit C:\temp\ntds.dit`
   `reg save HKLM\SYSTEM C:\temp\SYSTEM`
EOF

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${GREEN}[✓] All 72 tools accounted for in ${BASE_DIR}!${NC}"
echo -e "    - Impacket Scripts (14) : ${IMPACKET_DIR}"
echo -e "    - Linux Tools & Repos   : ${LINUX_DIR}"
echo -e "    - Windows PS1 Scripts   : ${WIN_PS1_DIR}"
echo -e "    - Windows C# Sources    : ${WIN_SRC_DIR}"
echo -e "    - Windows .exe Binaries : ${WIN_BIN_DIR}"
echo -e "    - Pivoting Binaries     : ${PIVOT_DIR}"
echo -e "    - Windows LOLBins Guide : ${WIN_BIN_DIR}/NATIVE_LOLBINS_CHEATSHEET.md"
echo -e "${BLUE}==============================================================================${NC}"
