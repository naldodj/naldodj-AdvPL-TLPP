# naldodj-AdvPL-TLPP

Curso de AdvPL & TLPP

## Pré-Requisitos

+ Sistema Operacional Windows 10 (64 bits)
    + [WSL Manual](https://learn.microsoft.com/en-us/windows/wsl/install-manual)
    + [WSL Instalação](https://learn.microsoft.com/en-us/windows/wsl/install)
+ [vsCode (Visual Studio Code)](https://code.visualstudio.com/)
    + [Portuguese (Brazil) Language Pack for Visual Studio Code ](https://marketplace.visualstudio.com/items?itemName=MS-CEINTL.vscode-language-pack-pt-BR)
+ [doker](https://www.docker.com/)
+ TOTVS
    + [TOTVS Developer Studio for VSCode (AdvPL, TLPP e 4GL)](https://marketplace.visualstudio.com/items?itemName=totvs.tds-vscode)
    + [Advpl](https://marketplace.visualstudio.com/items?itemName=KillerAll.advpl-vscode)
    + [ Protheus Dev SandBox](https://marketplace.visualstudio.com/items?itemName=totvs.protheus-dev-sandbox)
+ GitHub
    + [Criar Conta](https://github.com/signup)
    + [GitHub Desktop](https://desktop.github.com/)
    + [AdvPL-TLPP](https://github.com/naldodj/naldodj-AdvPL-TLPP/)
    + TortoiseGit
        + [git for windows](https://gitforwindows.org/)
        + [TortoiseGit](https://tortoisegit.org/download/)

## Preparação do Ambiente

+ [Instale o vsCode](https://code.visualstudio.com/)
    ![image](https://user-images.githubusercontent.com/102384575/210174242-5f2ab7d9-4a6f-4886-9c38-c09e8beb8b9c.png)    
    ![image](https://user-images.githubusercontent.com/102384575/210174885-b46193de-97d5-4baf-8a7b-4271b379742c.png)

+ Configurando o vsCode para PT-Br    
    ![image](https://user-images.githubusercontent.com/102384575/210175371-06be43ab-b754-41da-9075-70e0d2413f9b.png)    
    ![image](https://user-images.githubusercontent.com/102384575/210175149-e178826b-a90a-487b-b3a2-366fc6730ba0.png)    
    ![image](https://user-images.githubusercontent.com/102384575/210175170-c868bcbf-ffd7-4ec5-8bf6-225fe950c8ba.png)    
    * Reinicie o vsCode para aplicar a nova linguagem
    ![image](https://user-images.githubusercontent.com/102384575/210175219-eb8e5d39-363e-4465-9e95-5b481d86e19f.png)

+ [Habilite o WSL no Windows](https://learn.microsoft.com/en-us/windows/wsl/install-manual)
   ![image](https://user-images.githubusercontent.com/102384575/210174171-33ea086b-95dc-462b-8a2c-57aef2cc4750.png)
    + [Instale o doker](https://www.docker.com/)
    ![image](https://user-images.githubusercontent.com/102384575/210174305-d6d327df-c395-4b07-9b9e-4af0282182a0.png)

+ [Crie uma Conta no GitHub](https://github.com/signup)
    ![image](https://user-images.githubusercontent.com/102384575/210174429-75d0cc1f-fd63-414e-8e5f-dd001d433e96.png)

+ [Instale o GitHub DeskTop](https://desktop.github.com/)
    ![image](https://user-images.githubusercontent.com/102384575/210174444-8d0e3a63-4f3b-4d19-b7de-5b6574088b35.png)

+ [Instale o git for windows](https://gitforwindows.org/)
    ![image](https://user-images.githubusercontent.com/102384575/210174497-b3691642-fb01-4ece-8622-91a11bff1375.png)

+ [Instale o TortoiseGit](https://tortoisegit.org/download/)
    ![image](https://user-images.githubusercontent.com/102384575/210174559-366a76cc-6315-45e5-a45a-981bb783fbfa.png)
    
    * Obs.: Se preferir o TortoiseGit em pt-BR instale o Language Pack correspondente.
    ![image](https://user-images.githubusercontent.com/102384575/210174632-11d00aa7-7c37-498b-b7e3-36aeac530c22.png)
    ![image](https://user-images.githubusercontent.com/102384575/210174655-a126f1da-3884-4abc-ac8b-d3acfa5eb30a.png)

## Configurando o ambiente

+ Aplicando o pacote de tradução pt-BR ao vsCode (Visual Studio Code)
    + Abra o vsCode

+ Crie uma pasta c:\GitHub
    + [Acesse AdvPL-TLPP efetue o Fork do Repositório e copie a URL](https://github.com/naldodj/naldodj-AdvPL-TLPP/)
        
        + Efetuando o Fork
        
        ![image](https://user-images.githubusercontent.com/102384575/210173643-313b0e3e-0655-4454-8799-0e3e0d107ca0.png)
        
        ![image](https://user-images.githubusercontent.com/102384575/210173670-e8512ecf-ebb7-4746-80df-a538df0674f5.png)    

        + Copiando a URL 
        ![image](https://user-images.githubusercontent.com/102384575/210173586-3e80e3c9-0679-4471-a7b9-2b5803455dac.png)
    
        + Abra o Explorador de Arquivos do Windows
            + Vá para a pasta c:\GitHub
            + Estando na pasta c:\GitHub clique com o Botão Direito do Mouse. Irão aparecer mais opções: Selecione TortoiseGit\Clone
            
                ![image](https://user-images.githubusercontent.com/102384575/210172690-6dd1c385-7981-4f35-907b-0e106c7f7d1b.png)
                
                + Clique em OK para Clonar o repositório
                
                    ![image](https://user-images.githubusercontent.com/102384575/210172802-b359f61d-c1f9-4233-b10e-43a43e3be0fc.png)
                    
                    O clone do repositório deverá ser feito em c:\GitHub (que será o root dos seus projetos)
                    
                    ![image](https://user-images.githubusercontent.com/102384575/210172995-c7240d61-2794-4cf1-a941-ee39615aadd6.png)

    + Abra o vsCode (Visual Studio Code)
        + Clique em Arquivo\Abir o Workspace a partir do Arquivo... 
        
        ![image](https://user-images.githubusercontent.com/102384575/210173217-d4786daf-7b06-4a5e-9054-1dae4754297a.png)
        
        + Selecione o arquivo curso.code-workspace e clique em "Abrir"
        
        ![image](https://user-images.githubusercontent.com/102384575/210173458-48bcd97e-4f10-4d7f-8f3a-70a181b2f7f8.png)
        
        + Selecione CURSO (WORKSPACE) para expandir o espaço de trabalho.
        
        ![image](https://user-images.githubusercontent.com/102384575/210173502-b48a3e9f-0a98-4026-b52d-bb7f5fcc269c.png)
        
        ![image](https://user-images.githubusercontent.com/102384575/210173535-85756836-1db4-48f7-ad57-3a8ad01addbc.png)        

## Reference

+ TDN
    + [AdvPL](https://tdn.totvs.com/display/tec/AdvPL)
    + [TLpp](https://tdn.totvs.com.br/display/tec/TLpp)

## Contributors

## License

