#include "totvs.ch"
#include "fwmvcdef.ch"

#define MVC_TITLE " :: Inserção de Treinamento"

/*
    X3_VALID
        RA6_ENTIDA => NaoVazio() .And. ExistCpo("RA0") .And. IF(FWISINCALLSTACK("U_INSTRM"),.t.,Tr010Desc(.F.))
        RA6_CURSO => NaoVazio() .And. ExistCpo("RA1") .And. IF(FWISINCALLSTACK("U_INSTRM"),.t.,Tr010Desc(.F.))
    X3_RELACAO
        RA6_DESC => IF(FWISINCALLSTACK("U_INSTRM"),SPACE(GETSX3CACHE("RA6_DESC","X3_TAMANHO")),Tr010Desc(.T.))
*/

function U_INSTRM() as variant
    local cSvFilAnt:=&("cFilAnt")
    local xRet as variant
    private cCadastro:=MVC_TITLE as character
    private INCLUI:=.T. as logical
    xRet:=FWExecView(MVC_TITLE,"VIEWDEF.INSERTTRAINING",MODEL_OPERATION_INSERT)
    SetFilAnt(cSvFilAnt)
return(xRet)

static function ModelDef() as object

    local aFieldsDet as array

    local bLOkVld as codeblock
    local bTOkVld as codeblock

    local cFieldsDet as character
    
    local oModel as object
    local oHeader as object
    local oDetail as object

    aFieldsDet:=getFieldsDet()

    oModel:=MPFormModel():New("INSERTTRAINING",{||.T.}/*bPre*/,{||.T.}/*bPos*/,/*bCommit*/,{||.T.}/*bCancel*/)
    oModel:SetDescription(MVC_TITLE)

    oModel:bCommit:={|oModel|ZZ4TTSCommit(oModel)}

    oHeader:=FWFormModelStruct():New()
    oHeader:addTable("",{"C_FAKE"},"::"/*MVC_TITLE*/,{||""})
    oHeader:addField("FAKE","FAKE","C_FAKE","C",1)

    oModel:addFields("INSERTTRAINING_MASTER",/*cOwner*/,oHeader,/*bPre*/,/*bPost*/,{|oMdl|{""}})
    
    bDetail:={|cField|(cFieldsDet:=Upper(allTrim(cField)),(aScan(aFieldsDet,{|cField|(Upper(allTrim(cField))==cFieldsDet)})>0))}
    oDetail:=FWFormStruct(1,"RA4",bDetail)

    bLOkVld:={|oGrid|GridVldLOK(oGrid,oModel,aFieldsDet)}
    bTOkVld:={|oGrid|GridVldTOK(oGrid,oModel,aFieldsDet)}

    oModel:AddGrid("INSERTTRAINING_DETAIL","INSERTTRAINING_MASTER",oDetail,{||.T.},bLOkVld,{||.T.},bTOkVld,{||.T.})
    
    oModel:GetModel("INSERTTRAINING_DETAIL"):SetUniqueLine({"RA4_FILIAL","RA4_MAT","RA4_CURSO","RA4_DATAIN"})
    oModel:GetModel("INSERTTRAINING_DETAIL"):SetDescription(MVC_TITLE)
    oModel:GetModel("INSERTTRAINING_DETAIL"):SetUseOldGrid(.T.)

    oModel:setActivate({|oModel|onActivate(oModel)})

    return(oModel)

static function ViewDef() as object

    local aFieldsDet as array
    local aFieldsSXB as array

    local bDetail as codeblock
    local bGDSeek as codeblock
    local bReplicateLine as codeblock

    local cField as character
    local cFieldsDet as character

    local nATSXB as numeric

    local oView as object
    local oModel as object
    local oDetail as object
    local oHeader as object

    aFieldsDet:=getFieldsDet()
    
    aFieldsSXB:=Array(0)
    aAdd(aFieldsSXB,{"RA4_CURSO","U__RA1"})
    aAdd(aFieldsSXB,{"RA4_ENTIDA","U__RA6"})

    oHeader:=FWFormViewStruct():New()
    oHeader:addField("C_FAKE","01","FAKE","FAKE",/*aHelp*/,"C")

    bDetail:={|cField|(cFieldsDet:=Upper(allTrim(cField)),(aScan(aFieldsDet,{|cField|(Upper(allTrim(cField))==cFieldsDet)})>0))}
    oDetail:=FWFormStruct(2,"RA4",bDetail)

    oDetail:addField("RA4_FILIAL","00","Filial","Filial do sistema",/*aHelp*/,"C")
    
    //Redefinir as consultas F3
    aEval(;
        oDetail:GetFields(),{|x|;
            cField:=x[MVC_VIEW_IDFIELD],;
            nATSXB:=aScan(aFieldsSXB,{|x|x[1]==cField}),;
            x[MVC_VIEW_LOOKUP]:=if(nATSXB>0,aFieldsSXB[nATSXB][2],getSX3Cache(x[MVC_VIEW_IDFIELD],"X3_F3"));
        })

    oModel:=FWLoadModel("INSERTTRAINING")

    oView:=FWFormView():New()
    oView:SetModel(oModel)

    oView:AddField("INSERTTRAINING_MASTER",oHeader,"INSERTTRAINING_MASTER")
    oView:AddGrid("INSERTTRAINING_DETAIL",oDetail,"INSERTTRAINING_DETAIL")

    oView:CreateHorizontalBox("INSERTTRAINING_BOX_MASTER",0)
    oView:CreateHorizontalBox("INSERTTRAINING_BOX_DETAIL",100)

    oView:SetOwnerView("INSERTTRAINING_MASTER","INSERTTRAINING_BOX_MASTER")
    oView:SetOwnerView("INSERTTRAINING_DETAIL","INSERTTRAINING_BOX_DETAIL")

    oView:EnableControlBar(.F.)
    oView:lForceSetOwner:=.T.

    bReplicateLine:={||GDReplicateLine(oModel),SetKey(VK_F5,bReplicateLine)}
    SetKey(VK_F5,bReplicateLine)
    oView:AddUserButton("Duplicar Linha <F5>","",bReplicateLine)

    bGDSeek:={||GDSeek(nil,OemtoAnsi("Pesquisar nos Detalhes"),nil,nil,.T.,oModel:GetModel("INSERTTRAINING_DETAIL"))}
    oView:AddUserButton("Pesquisar Detalhes","",bGDSeek)

    return(oView)

static function GDReplicateLine(oModel) as numeric

    local aFieldsDet as array
    local aNoReplicate as array

    local cField as character
    
    local nField as numeric
    local nFields as numeric

    local nLines as numeric
    local nLineAT as numeric
    local nGDReplicateLine:=(-1) as numeric

    local oModelGrid as object
    local oFWViewActive as object

    local xValue as variant

    begin sequence

        if (!FWISInCallStack("U_INSTRM"))
            break
        endif

        oModelGrid:=oModel:GetModel("INSERTTRAINING_DETAIL")
        
        nLines:=oModelGrid:Length()
        nLineAT:=oModelGrid:GetLine()
        
        nGDReplicateLine:=oModelGrid:AddLIne()
        
        if (nGDReplicateLine>nLines)
            aNoReplicate:=array(0)
            aAdd(aNoReplicate,"RA4_MAT")
            aAdd(aNoReplicate,"RA4_NOME")
            aAdd(aNoReplicate,"RA4_UNOMEL")
            aAdd(aNoReplicate,"RA4_DESCCU")    
            aAdd(aNoReplicate,"RA4_DESCEN")
            aFieldsDet:=getFieldsDet()    
            nFields:=Len(aFieldsDet)
            for nField:=1 to nFields
                cField:=aFieldsDet[nField]
                if (aScan(aNoReplicate,{|fld|(fld==cField)})>0)
                    loop
                endif
                xValue:=oModelGrid:GetValue(cField,nLineAT)
                oModelGrid:GoLine(nGDReplicateLine)
                oModelGrid:SetValue(cField,xValue,.T.)
            next nField
            FWFreeArray(@aFieldsDet)
            FWFreeArray(@aNoReplicate)
            oFWViewActive:=FWViewActive()
            oFWViewActive:Refresh()
        endif

    end sequence

return(nGDReplicateLine)

static function MenuDef() as array
    
    local aRotina:=array(0) as array

    ADD OPTION aRotina TITLE "Incluir" ACTION "VIEWDEF.INSERTTRAINING" OPERATION MODEL_OPERATION_INSERT ACCESS 0 //OPERATION 3

    return(aRotina)

static function GridVldLOK(oGrid as object,oModel as object,aFieldsDet as array) as logical

    local cField as character
    local cKeySeek as character
    
    local lLinhaOK:=.T. as logical

    local nATRow as numeric

    local nField as numeric
    local nFields as numeric

    local nRA4Order as numeric
    local nRA6Order as numeric

    nFields:=Len(aFieldsDet)

    nATRow:=oGrid:GetLine()

    begin sequence
        
        if (oGrid:IsDeleted())
            break
        endif
        
        for nField:=1 to nFields
            cField:=aFieldsDet[nField]
            lLinhaOK:=(!empty(oGrid:GetValue(cField)))
            if (!lLinhaOK)
                Help(nil,nil,"OBRIGAT",nil,PadR("Verifique o preenchimento do(s) campo(s) ("+cField+") Linha ("+cValToChar(nATRow)+")",255),1,0)
                break
            endif
        next nField
        
        cKeySeek:=FWFldGet("RA4_FILIAL",nATRow,oModel,.F.)
        cKeySeek+=FWFldGet("RA4_MAT",nATRow,oModel,.F.)

        SRA->(dbSetOrder(1))
        lLinhaOK:=SRA->(MsSeek(cKeySeek,.F.))
        if (!lLinhaOK)
            cField:="RA4_FILIAL,RA4_MAT"
            Help(nil,nil,"OBRIGAT",nil,PadR("Verifique o preenchimento do(s) campo(s) ("+cField+") Linha ("+cValToChar(nATRow)+")",255),1,0)
            break
        endif

        nRA4Order:=RetOrder("RA4","RA4_FILIAL+RA4_MAT+RA4_CALEND+RA4_CURSO+RA4_TURMA+RA4_SINONI+DTOS(RA4_DATAIN)",.T.) 
        if (nRA4Order==0)
            nRA4Order:=RetOrder("RA4","RA4_FILIAL+RA4_MAT+RA4_CURSO")
            cKeySeek+=FWFldGet("RA4_CURSO",nATRow,oModel,.F.)
        else
            //RA4_FILIAL+RA4_MAT+RA4_CALEND+RA4_CURSO+RA4_TURMA+RA4_SINONI+DTOS(RA4_DATAIN)
            cKeySeek+=Space(GetSX3Cache("RA4_CALEND","X3_TAMANHO"))
            cKeySeek+=FWFldGet("RA4_CURSO",nATRow,oModel,.F.)
            cKeySeek+=Space(GetSX3Cache("RA4_TURMA","X3_TAMANHO"))
            cKeySeek+=Space(GetSX3Cache("RA4_SINONI","X3_TAMANHO"))
            cKeySeek+=DToS(FWFldGet("RA4_DATAIN",nATRow,oModel,.F.))
        endif

        RA4->(dbSetOrder(nRA4Order))
        lLinhaOK:=RA4->(!MsSeek(cKeySeek,.F.))
        if (!lLinhaOK)
            Help(nil,nil,"JAEXISTE",nil,PadR("Já Existe Informação deste curso para o Funcionário Linha ("+cValToChar(nATRow)+")",255),1,0)
            break
        endif

        lLinhaOK:=(FWFldGet("RA4_DATAIN",nATRow,oModel,.F.)<=FWFldGet("RA4_DATAFI",nATRow,oModel,.F.))
        if (!lLinhaOK)
            Help(nil,nil,"RA4_DATAFI",nil,PadR("Data Final maior que Data Inicial ("+cValToChar(nATRow)+")",255),1,0)
            break
        endif

        nRA6Order:=retOrder("RA6","RA6_FILIAL+RA6_ENTIDA+RA6_CURSO")
        RA6->(dbSetOrder(nRA6Order))
        cKeySeek:=xFilial("RA6",FWFldGet("RA4_FILIAL",nATRow,oModel,.F.))
        cKeySeek+=FWFldGet("RA4_ENTIDA",nATRow,oModel,.F.)
        cKeySeek+=FWFldGet("RA4_CURSO",nATRow,oModel,.F.)
        lLinhaOK:=RA6->(MsSeek(cKeySeek,.F.))
        if (!lLinhaOK)
            Help(nil/*cRotina*/,nil/*nLinha*/,"RA4_ENTIDA"/*cCampo*/,nil/*cNome*/,PadR("O Código da Entidade informada não é válido. "+GetSX3Cache("RA4_CURSO","X3_TITULO")+" não vinculado: ("+FWFldGet("RA4_CURSO",nATRow,oModel,.F.)+") ("+cValToChar(nATRow)+").",255)/*cMensagem*/,1/*nLinha1*/,0/*nColuna*/,/*lPop*/,/*hWnd*/,/*nHeight*/,/*nWidth*/,/*lGravaLog*/,{"Informe um Código de Entidade Válido."}/*aSoluc*/)
            break
        endif

    end sequence

    return(lLinhaOK)    

static function GridVldTOK(oGrid as object,oModel as object,aFieldsDet as array) as logical

    local lTudoOK as logical

    local nRow as numeric
    local nRows as numeric
    local nATRow as numeric
    
    nATRow:=oGrid:GetLine()
    nRows:=oGrid:Length()

    for nRow:=1 to nRows
        oGrid:GoLine(nRow)
        if (oGrid:IsDeleted())
            loop
        endif
        lTudoOK:=GridVldLOK(@oGrid,oModel,@aFieldsDet)
        if (!lTudoOK)
            exit
        endif
    next nRow

    if (!lTudoOK)
        oGrid:GoLine(nRow)
    else
        oGrid:GoLine(nATRow)
    endif

    return(lTudoOK)

static function onActivate(oModel) as variant
    if (oModel:GetOperation()==MODEL_OPERATION_INSERT)
        FwFldPut("C_FAKE","0",/*nLinha*/,oModel)
    endif
return    

static function getFieldsDet() as aray

    local aFieldsDet as array

    aFieldsDet:=array(0)

    aAdd(aFieldsDet,"RA4_FILIAL")
    aAdd(aFieldsDet,"RA4_MAT")
    aAdd(aFieldsDet,"RA4_NOME")
    aAdd(aFieldsDet,"RA4_ULIDER")
    aAdd(aFieldsDet,"RA4_UNOMEL")
    aAdd(aFieldsDet,"RA4_CURSO")
    aAdd(aFieldsDet,"RA4_DESCCU")    
    aAdd(aFieldsDet,"RA4_ENTIDA")
    aAdd(aFieldsDet,"RA4_DESCEN")
    aAdd(aFieldsDet,"RA4_DURACA")
    aAdd(aFieldsDet,"RA4_UNDURA")
    aAdd(aFieldsDet,"RA4_HORAS")
    aAdd(aFieldsDet,"RA4_DATAIN")
    aAdd(aFieldsDet,"RA4_DATAFI")
    aAdd(aFieldsDet,"RA4_UMODAL")
    aAdd(aFieldsDet,"RA4_UAVREC")
    aAdd(aFieldsDet,"RA4_EFICSN")

return(aFieldsDet)

function u_INSERTTRAINING() as variant
    local aParameter as array
    local xRet:=.F. as variant
    begin sequence
        if (!type("ParamIXB")=="A")
            break
        endif
        aParameter:=&("ParamIXB")
        xRet:=INSERTTRAINING(@aParameter)
    end sequence
    return(xRet)

static function INSERTTRAINING(aParameter as array) as variant

    local cIDPonto as character
    local cIDModel as character

    local cObjMVCClassName as character

    local nParameters as numeric

    local oObjMVC as object

    local xRet:=.T. as variant

    begin sequence

        nParameters:=len(aParameter)
        
        oObjMVC:=aParameter[1]
        cObjMVCClassName:=oObjMVC:ClassName()
        
        cIDPonto:=aParameter[2]
        cIDModel:=aParameter[3]

        if (cIDPonto=="MODELPOS")
            xRet:=.T.
            break
        endif

        if (cIDPonto=="FORMPOS")
            xRet:=.T.
            break
        endif

        if (cIDPonto=="FORMLINEPRE")
            if ((nParameters>=5).and.(aParameter[5]=="DELETE"))
                xRet:=.T.
            endif
            break
        endif

        if (cIDPonto=="FORMLINEPOS")
            xRet:=.T.
            break
        endif

        if (cIDPonto=="MODELCOMMITTTS")
            if ((cIDModel=="INSERTTRAINING_DETAIL").and.(cObjMVCClassName=="FWFORMGRID"))
                xRet:=.T.
            else
                xRet:=.T.
            endif
            break
        endif

        if (cIDPonto=="MODELCOMMITNTTS")
            xRet:=.T.
            break
        endif

        if (cIDPonto=="FORMCOMMITTTSPRE")
            xRet:=.T.
            break
        endif

        if (cIDPonto=="FORMCOMMITTTSPOS")
            xRet:=.T.
            break
        endif

        if (cIDPonto=="MODELCANCEL")
            xRet:=.T.
            break
        endif

        if (cIDPonto=="BUTTONBAR")
            xRet:=array(0)
            break
        endif

    end sequence

    return(xRet)

static function SetFilAnt(cFil) as character
    local cSvFilAnt:=&("cFilAnt") as character
    if (valType("cFilAnt")=="C")
        cSvFilAnt:=&("cFilAnt")
        if (cFil!=cSvFilAnt)
            &("cFilAnt"):=cFil
            FWSM0Util():setSM0PositionBycFilAnt()
        endif
    endif
return(cSvFilAnt)

static function ZZ4TTSCommit(oModel) as logical

    local aSaveRows as array

    local cSvcArqTab:=&("cArqTab") as character

    local lZZ4TTSCommit as logical

    local nAT as numeric

    local oSaveModel as object

    aSaveRows:=FWSaveRows()

    oSaveModel:=FWModelActive(oModel)

    //Altera o Modo de Acesso da Tabela RA4 para garantir a Gravação das Filiais informadas pelo usuário
    //Desta Forma FWFormCommit não irá substituir a Filial Gravara
    nAT:=AT("RA4",&("cArqTab"))
    if (nAT>0)
        &("cArqTab"):=SubStr(&("cArqTab"),1,nAT+2)+"C"+SubStr(&("cArqTab"),nAT+4)
    else
        &("cArqTab")+="RA4"+"C"+"/"
    endif

    lZZ4TTSCommit:=FWFormCommit(oModel)

    &("cArqTab"):=cSvcArqTab

    FWModelActive(oSaveModel)

    FWRestRows(aSaveRows)

    return(lZZ4TTSCommit)

function u_RA1SXBFilter()
return(SXBINSERTTRAINING():RA1Filter())

function u_RA6SXBFilter()
return(SXBINSERTTRAINING():RA6Filter())

static procedure __Dummy()

    if (.F.)
        __Dummy()
        MODELDEF()
        VIEWDEF()
        MENUDEF()
    endif

    return
