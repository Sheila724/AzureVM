# 🚀 Azure VM Automation Script

**Autor:** Sheila Alves  

Script em **PowerShell** para criar, gerenciar e remover máquinas virtuais **Ubuntu 24.04 LTS** no **Microsoft Azure** utilizando o **Azure CLI**.

---

## ✨ Funcionalidades

- Criação automática de:
  - Resource Group  
  - Virtual Network (VNet) e Subnet  
  - Network Security Group (NSG) com regras SSH, HTTP e HTTPS  
  - Public IP  
  - Network Interface (NIC)  
  - Máquina Virtual Ubuntu 24.04 LTS
- Comandos de gerenciamento:
  - Parar, iniciar e desalocar VM  
  - Consultar status da VM  
  - Remover VM e recursos dependentes automaticamente  

---

## 🛠️ Pré-requisitos

- PowerShell 7+  
- Azure CLI instalada  
- Conta no Microsoft Azure  
- Permissões para criar recursos  

---

## ⚙️ Parâmetros do script

| Parâmetro       | Obrigatório | Descrição |
|-----------------|------------|-----------|
| `-VmName`       | ✅ Sim     | Nome da VM |
| `-ResourceGroup`| ✅ Sim     | Grupo de recursos |
| `-Location`     | ✅ Sim     | Região do Azure (ex: `brazilsouth`) |
| `-AdminUser`    | ✅ Sim     | Usuário administrador da VM |
| `-AdminPassword`| ❌ Não     | Senha do administrador (entrada segura se não informada) |

> A senha deve ter **mínimo 12 caracteres** incluindo letras maiúsculas, minúsculas, números e símbolos.

---

## 💻 Como usar

### 1️⃣ Criar VM
```powershell
.\Create-AzureVm.ps1 -VmName "MinhaVM" -ResourceGroup "RG-Trabalho" -Location "brazilsouth" -AdminUser "aluno"
```
O script exibirá o IP público da VM após a criação

## 2️⃣ Gerenciar VM
# Parar VM
Stop-VM -VmName "MinhaVM" -ResourceGroup "RG-Trabalho"

# Iniciar VM
Start-VM -VmName "MinhaVM" -ResourceGroup "RG-Trabalho"

# Desalocar VM (economia de custos)
Deallocate-VM -VmName "MinhaVM" -ResourceGroup "RG-Trabalho"

# Consultar status
Get-VMStatus -VmName "MinhaVM" -ResourceGroup "RG-Trabalho"

# Remover VM e recursos dependentes
Remove-VMWithDeps -VmNameToRemove "MinhaVM" -ResourceGroupToRemove "RG-Trabalho"

## ⚠️ Observações
- O script faz login automático no Azure CLI se necessário
- Remove automaticamente recursos dependentes ao deletar a VM para evitar custos extras.
- Ideal para testes, aprendizado e apresentações

## 📂 Estrutura do repositório
````
/home/sheila/
├── Create-AzureVm.ps1
└── README.md
````
