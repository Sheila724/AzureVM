<#
Create-AzureVM.ps1
Autor: Sheila Alves
Descrição:
  Script para criar, gerenciar e remover máquinas virtuais Ubuntu 24.04 LTS no Microsoft Azure
  usando o Azure CLI integrado ao PowerShell.
  
  Este script cria automaticamente os recursos necessários (Grupo de Recursos, NSG, VNet, Subnet, IP Público e NIC)
  e permite remover todos eles quando a VM for excluída.

Parâmetros obrigatórios:
  -VmName        → Nome da máquina virtual
  -ResourceGroup → Grupo de recursos
  -Location      → Região (ex: brazilsouth)
  -AdminUser     → Nome do usuário administrador
  -AdminPassword → (opcional) Senha do administrador (pode ser informada via prompt seguro)

Funções disponíveis:
  - Create-VM          → Cria a VM e recursos associados
  - Remove-VMWithDeps  → Remove VM, IP e NIC
  - Stop-VM / Start-VM / Deallocate-VM / Get-VMStatus → Controle da instância
#>

param(
  [Parameter(Mandatory = $true)] [string]$VmName,
  [Parameter(Mandatory = $true)] [string]$ResourceGroup,
  [Parameter(Mandatory = $true)] [string]$Location,
  [Parameter(Mandatory = $true)] [string]$AdminUser,
  [string]$AdminPassword
)

# ===============================
# Configurações fixas do projeto
# ===============================
$VM_IMAGEM = "Canonical:0001-com-ubuntu-server-lts:24_04-lts:latest"
$VM_SIZE = "Standard_B1ms"
$PUBLIC_IP_SKU = "Standard"

$VNET_NAME = "$($VmName)-vnet"
$SUBNET_NAME = "$($VmName)-subnet"
$NSG_NAME = "$($VmName)-nsg"
$NIC_NAME = "$($VmName)-nic"
$PUBLIC_IP_NAME = "$($VmName)-pip"
$OS_DISK_NAME = "$($VmName)-osdisk"

$ADDRESS_PREFIX = "10.0.0.0/16"
$SUBNET_PREFIX = "10.0.1.0/24"

# ===============================
# Funções auxiliares
# ===============================

function Ensure-AzLogin {
  try {
    az account show -o none 2>$null
    if ($LASTEXITCODE -eq 0) {
      Write-Host "✔ Sessão Azure CLI detectada."
    } else {
      throw
    }
  } catch {
    Write-Host "🔐 Não autenticado. Realizando login..."
    az login --use-device-code | Out-Null
  }
}

function Convert-SecureToPlain([System.Security.SecureString]$secure) {
  if (-not $secure) { return $null }
  $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
  } finally {
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
  }
}

# ===============================
# Criação da VM e recursos
# ===============================
function Create-VM {
  param(
    [string]$VmName,
    [string]$ResourceGroup,
    [string]$Location,
    [string]$AdminUser,
    [string]$AdminPassword
  )

  Write-Host "📦 Criando/checando Resource Group: $ResourceGroup ..."
  az group create --name $ResourceGroup --location $Location -o none

  Write-Host "🧱 Criando Network Security Group: $NSG_NAME ..."
  az network nsg create -g $ResourceGroup -n $NSG_NAME --location $Location -o none

  Write-Host "🔒 Criando regras NSG: SSH(22), HTTP(80), HTTPS(443) ..."
  az network nsg rule create -g $ResourceGroup --nsg-name $NSG_NAME -n AllowSSH --priority 1000 --access Allow --protocol Tcp --direction Inbound --destination-port-ranges 22 -o none
  az network nsg rule create -g $ResourceGroup --nsg-name $NSG_NAME -n AllowHTTP --priority 1001 --access Allow --protocol Tcp --direction Inbound --destination-port-ranges 80 -o none
  az network nsg rule create -g $ResourceGroup --nsg-name $NSG_NAME -n AllowHTTPS --priority 1002 --access Allow --protocol Tcp --direction Inbound --destination-port-ranges 443 -o none

  Write-Host "🌐 Criando VNet/Subnet: $VNET_NAME / $SUBNET_NAME ..."
  az network vnet create -g $ResourceGroup -n $VNET_NAME --address-prefix $ADDRESS_PREFIX --subnet-name $SUBNET_NAME --subnet-prefix $SUBNET_PREFIX -o none

  Write-Host "🌍 Criando IP Público: $PUBLIC_IP_NAME ..."
  az network public-ip create -g $ResourceGroup -n $PUBLIC_IP_NAME --sku $PUBLIC_IP_SKU --allocation-method Static -o none

  Write-Host "🔗 Criando NIC (associando IP e NSG): $NIC_NAME ..."
  az network nic create -g $ResourceGroup -n $NIC_NAME `
    --vnet-name $VNET_NAME `
    --subnet $SUBNET_NAME `
    --network-security-group $NSG_NAME `
    --public-ip-address $PUBLIC_IP_NAME -o none

  Write-Host "💻 Criando VM: $VmName (Ubuntu 24.04 LTS)..."
  az vm create `
    --resource-group $ResourceGroup `
    --name $VmName `
    --image $VM_IMAGEM `
    --size $VM_SIZE `
    --admin-username $AdminUser `
    --admin-password $AdminPassword `
    --nics $NIC_NAME `
    --location $Location `
    --os-disk-name $OS_DISK_NAME `
    --nic-delete-option delete `
    --public-ip-delete-option delete `
    --output table

  Write-Host "`n✅ VM criada com sucesso!"
  az vm list-ip-addresses --resource-group $ResourceGroup --name $VmName --output table
}

# ===============================
# Remoção completa
# ===============================
function Remove-VMWithDeps {
  param(
    [Parameter(Mandatory=$true)][string]$VmNameToRemove,
    [Parameter(Mandatory=$true)][string]$ResourceGroupToRemove
  )

  Write-Host "🗑️ Removendo VM e dependências..."

  $vmExists = az vm show -g $ResourceGroupToRemove -n $VmNameToRemove -o none 2>$null
  if ($?) {
    Write-Host "Removendo VM: $VmNameToRemove ..."
    az vm delete -g $ResourceGroupToRemove -n $VmNameToRemove --yes
  }

  Write-Host "Removendo IP Público e NIC (se existirem)..."
  az network public-ip delete -g $ResourceGroupToRemove -n "$VmNameToRemove-pip" 2>$null
  az network nic delete -g $ResourceGroupToRemove -n "$VmNameToRemove-nic" 2>$null

  Write-Host "🧹 Limpeza concluída."
}

# ===============================
# Gerenciamento rápido
# ===============================
function Stop-VM { param([string]$VmName,[string]$ResourceGroup)
  Write-Host "⏹ Parando VM..."
  az vm stop -g $ResourceGroup -n $VmName
}

function Deallocate-VM { param([string]$VmName,[string]$ResourceGroup)
  Write-Host "💤 Desalocando VM (economia de custos)..."
  az vm deallocate -g $ResourceGroup -n $VmName
}

function Start-VM { param([string]$VmName,[string]$ResourceGroup)
  Write-Host "▶ Iniciando VM..."
  az vm start -g $ResourceGroup -n $VmName
}

function Get-VMStatus { param([string]$VmName,[string]$ResourceGroup)
  Write-Host "📡 Consultando status..."
  az vm get-instance-view -g $ResourceGroup -n $VmName --query "instanceView.statuses[1]" -o table
}

# ===============================
# Execução principal
# ===============================

Ensure-AzLogin

if (-not $AdminPassword) {
  Write-Host "🔑 Informe a senha para o usuário administrador:"
  $securePwd = Read-Host -AsSecureString "Senha (entrada oculta)"
  $AdminPassword = Convert-SecureToPlain $securePwd
}

if ($AdminPassword.Length -lt 12) {
  Write-Error "❌ A senha deve conter pelo menos 12 caracteres (com maiúscula, minúscula, número e símbolo)."
  exit 1
}

Create-VM -VmName $VmName -ResourceGroup $ResourceGroup -Location $Location -AdminUser $AdminUser -AdminPassword $AdminPassword

Write-Host "`nScript finalizado com sucesso. Comandos de gerenciamento:"
Write-Host "  Stop-VM -VmName $VmName -ResourceGroup $ResourceGroup"
Write-Host "  Start-VM -VmName $VmName -ResourceGroup $ResourceGroup"
Write-Host "  Deallocate-VM -VmName $VmName -ResourceGroup $ResourceGroup"
Write-Host "  Get-VMStatus -VmName $VmName -ResourceGroup $ResourceGroup"
Write-Host "  Remove-VMWithDeps -VmNameToRemove $VmName -ResourceGroupToRemove $ResourceGroup"
