#include "totvs.ch"
#include "dbstruct.ch"

function u_INSTRMRPT() as logical

    local cTmpAlias as character

    local lFilial as logical
    local lContinue:=.F. as logical
    local lAnalitico as logical
    local lSetCentury:=__SetCentury("on")

    local nFilial as numeric
    local nAnalitico as numeric

    local oTHMPergunte:=THashMap():New() as object

    begin sequence 

        lContinue:=Pergunte(@oTHMPergunte)
        if (!lContinue)
            break
        endif

        lContinue:=oTHMPergunte:Get("TipoRelatorio",@nAnalitico)
        if (!lContinue)
            break
        endif

        lAnalitico:=(nAnalitico==1)

        if (lAnalitico)
            MsAguarde({||lContinue:=QueryViewAnalitico(@oTHMPergunte,@cTmpAlias)},"Selecionando Dados no SGBD")
        else
            lContinue:=oTHMPergunte:Get("SintetizaPor",@nFilial)
            if (!lContinue)
                break
            endif
            lFilial:=(nFilial==1)
            if (lFilial)
                MsAguarde({||lContinue:=QueryViewFilialSintetico(@oTHMPergunte,@cTmpAlias)},"Selecionando Dados no SGBD")
            else
                MsAguarde({||lContinue:=QueryViewCentroDeCustoSintetico(@oTHMPergunte,@cTmpAlias)},"Selecionando Dados no SGBD")
            endif
        endif

        if (!lContinue)
            break
        endif

        Processa({||lContinue:=ExcelReport(@cTmpAlias,lAnalitico,lFilial)},"Gerando Arquivo")

    end sequence

    __SetCentury(if(lSetCentury,"on","off"))

    if ((!empty(cTmpAlias)).and.(select(cTmpAlias))>0)
        (cTmpAlias)->(dbCloseArea())
    endif

    FWFreeObj(oTHMPergunte)

    DelClassIntF()

return(lContinue)

static function ExcelReport(cTmpAlias as character,lAnalitico as logical,lFilial as logical) as logical

    local aCells:=Array(0) as array
    local aHeader as array
    local aHeaderTitle as array

    local cTipoRel:=(if(lAnalitico,"Analitico","Sintetico por "+if(lFilial,"Filial","Centro de Custo"))) as character
    local cTipoRelNoAccent:=FwNoAccent(cTipoRel) as character

    local cFile:=(ProcName()+"_"+strTran(cTipoRelNoAccent," ","_")+"_"+CriaTrab(nil,.F.)+".xml") as character
    local cFileTmp:=getTempPath() as character

    local cField as character
    local cColumn as character
    local cFieldType as character

    local cWorkSheet:="Relatorio de Cursos"  as character
    local cWBreak:=cWorkSheet as character
    local cTBreak:=cWBreak+" ("+cTipoRel+")" as character

    local cPicture as character

    local lTotal:=.F. as logical
    local lExcelReport:=.F. as logical

    local nField as numeric
    local nFields as numeric
    local nFieldAT as numeric

    local nAlign as numeric
    local nFormat as numeric

    local oMsExcel as object
    local oFWMSExcel as object

    local uCell as variant

    begin sequence

        ProcRegua(0)

        aHeaderTitle:={;
            {"RA_FILIAL","","",""},;
            {"RA_CC","","",""},;
            {"CTT_DESC01","Desc. C.C.","",""},;
            {"RA_MAT","","",""},;
            {"RA_NOME","","",""},;
            {"RA_CODFUNC","","",""},;
            {"RJ_DESC","Desc. Func.","",""},;
            {"RA4_CURSO","","",""},;
            {"RA1_DESC","Desc. Curso","",""},;
            {"RA4_ENTIDA","","",""},;
            {"RA0_DESC","Desc. Entidade","",""},;
            {"RA1_HORAS","","","__NOTRANSFORM__"},;
            {"RA4_DATAIN","","",""},;
            {"RA4_DATAFI","","",""},;
            {"RA1_CATEG","","",""},;
            {"AIQ_DESCRI","Desc. Categ.","",""},;
            {"RA4_UMODAL","","",""},;
            {"RA4_UAVREC","","",""},;
            {"RA4_EFICSN","","","__NOTRANSFORM__"},;
            {"RA4_HORAS","Horas Treinadas","","__NOTRANSFORM__"},;
            {"QTDPTREINO","Pessoas Treinadas","N","__NOTRANSFORM__"},;
            {"RD0_CODIGO","Cod.Lider.","",""},;
            {"RD0_NOME","Lideranca","",""};
        }

        nFields:=Len(aHeaderTitle)
        
        for nField:=1 to nFields
            nFieldAT:=nField
            cField:=aHeaderTitle[nFieldAT][1]
            if (empty(aHeaderTitle[nFieldAT][2]))
                aHeaderTitle[nFieldAT][2]:=allTrim(GetSX3Cache(cField,"X3_TITULO"))
            endif
            if (empty(aHeaderTitle[nFieldAT][3]))
                aHeaderTitle[nFieldAT][3]:=GetSX3Cache(cField,"X3_TIPO")
            endif
            if (aHeaderTitle[nFieldAT][4]!="__NOTRANSFORM__")
                aHeaderTitle[nFieldAT][4]:=GetSX3Cache(cField,"X3_PICTURE")
            endif
        next nField

        oFWMSExcel:=FWMsExcelEx():New()
        oFWMSExcel:AddworkSheet(cWorkSheet)
        oFWMSExcel:AddTable(cWBreak,cTBreak)

        aHeader:=(cTmpAlias)->(dbStruct())
        nFields:=Len(aHeader)

        for nField:=1 to nFields
            cField:=aHeader[nField][DBS_NAME]
            nFieldAT:=aScan(aHeaderTitle,{|x|x[1]==cField})
            cFieldType:=if(nFieldAT>0,aHeaderTitle[nFieldAT][3],aHeader[nField][DBS_TYPE])
            if (empty(cFieldType))
                cFieldType:=aHeader[nField][DBS_TYPE]
            endif
            nAlign:=if(cFieldType=="C",1,if(cFieldType=="N",3,2))
            //1-General,2-Number,3-Monetario,4-DateTime
            nFormat:=if(cFieldType=="D",4,if(cFieldType=="N",2,1))
            cColumn:=if(nFieldAT>0,aHeaderTitle[nFieldAT][2],cField)
            cColumn:=OemToAnsi(cColumn)
            lTotal:=(cFieldType=="N")
            oFWMSExcel:AddColumn(@cWBreak,@cTBreak,@cColumn,@nAlign,@nFormat,@lTotal)
        next nField

        while (cTmpAlias)->(!eof())

            IncProc()

            aSize(aCells,0)

            for nField := 1 to nFields
                uCell:=(cTmpAlias)->(FieldGet(nField))
                cField:=aHeader[nField][DBS_NAME]
                if (cField=="RA_FILIAL")
                    uCell+="-"+allTrim(FWFilialName(cEmpAnt,uCell,1))
                endif
                nFieldAT:=aScan(aHeaderTitle,{|x|x[1]==cField})
                cFieldType:=if(nFieldAT>0,aHeaderTitle[nFieldAT][3],aHeader[nField][DBS_TYPE])
                if (empty(cFieldType))
                    cFieldType:=aHeader[nField][DBS_TYPE]
                endif
                if (cFieldType=="D")
                    if (cFieldType!=aHeader[nField][DBS_TYPE])
                        uCell:=SToD(uCell)
                    endif
                endif
                cPicture:=if(nFieldAT>0,aHeaderTitle[nFieldAT][4],"")
                if (!(empty(cPicture)))
                    if (!(cPicture=="__NOTRANSFORM__"))
                        uCell:=allTrim(Transform(uCell,cPicture))
                    endif
                else
                    if (cFieldType=="D")
                        uCell:=DToC(uCell)
                    endif
                endif
                aAdd(aCells,uCell)
            next nField

            oFWMSExcel:AddRow(@cWBreak,@cTBreak,aClone(aCells))

            (cTmpAlias)->(dbSkip())

        end while

        MsAguarde({||oFWMSExcel:Activate(),oFWMSExcel:GetXMLFile(cFile),oFWMSExcel:DeActivate()},"Obtendo Saida")

        MsAguarde({||lExcelReport:=CpyS2T(cFile,cFileTmp,.T.)},"Copiando arquivo do Servidor")
        if (!lExcelReport)
            MsAguarde({||lExcelReport:=__CopyFile(cFile,cFileTmp+cFile)},"Copiando arquivo do Servidor")
        endif

        if (!lExcelReport)
            break
        endif

        fErase(cFile)

        oMsExcel:=MsExcel():New()
        cFileTmp+=cFile
        MsAguarde({||oMsExcel:WorkBooks:Open(cFileTmp)},"Carregando Arquivo Local")
        oMsExcel:SetVisible(.T.)
        oMsExcel:Destroy()
        oMsExcel:=FreeObj(oMsExcel)

    end sequence
    
    if (file(cFile))
        fErase(cFile)
    endif

    FWFreeArray(@aCells)
    FWFreeArray(@aHeader)
    FWFreeArray(@aHeaderTitle)

    if (valType(oFWMSExcel)=="O")
        oFWMSExcel:=FreeObj(oFWMSExcel)
    endif

    if (valtype(oMsExcel)=="O")
        oMsExcel:=FreeObj(oMsExcel)
    endif

    DelClassIntF()

return(lExcelReport)

static function QueryViewAnalitico(oTHMPergunte,cTmpAlias) as logical

    local cFilialDe as character
    local cFilialAte as character

    local cMatriculaDe as character
    local cMatriculaAte as character

    local cCursoDe as character
    local cCursoAte as character

    local cDataDe as character
    local cDataAte as character

    local cLiderancaDe as character
    local cLiderancaAte as character

    local cTipo as character

    local cTCGetDB:=TCGetDB() as character
    local cSQLLen as character
    local cSQLSubstr as character

    local lQueryView:=.F. as logical

    begin sequence 

        lQueryView:=oTHMPergunte:Get("FilialDe",@cFilialDe)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("FilialAte",@cFilialAte)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("MatriculaDe",@cMatriculaDe)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("MatriculaAte",@cMatriculaAte)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("CursoDe",@cCursoDe)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("CursoAte",@cCursoAte)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("DataDe",@cDataDe)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("DataAte",@cDataAte)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("LiderancaDe",@cLiderancaDe)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("LiderancaAte",@cLiderancaAte)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("Tipo",@cTipo)
        if (!lQueryView)
            break
        endif

        if ("*"$cTipo)
            cTipo:="*"
        endif

        cSQLLen:=if(cTCGetDB=="ORACLE","LENGTH","LEN")
        cSQLLen:="%"+cSQLLen+"%"
        
        cSQLSubstr:=if(cTCGetDB=="ORACLE","SUBSTR","SUBSTRING")
        cSQLSubstr:="%"+cSQLSubstr+"%"

        cTmpAlias:=getNextAlias()
        beginSQL alias cTmpAlias

            %noParser%

            column RA4_DATAIN as Date
            column RA4_DATAFI as Date

    SELECT SRA.RA_FILIAL
        ,SRA.RA_CC
        ,CTT.CTT_DESC01
        ,SRA.RA_MAT
        ,SRA.RA_NOME
        ,SRA.RA_CODFUNC
        ,SRJ.RJ_DESC
        ,RA4.RA4_CURSO
        ,RA1.RA1_DESC
        ,RA4.RA4_ENTIDA
        ,RA0.RA0_DESC
        ,RA1.RA1_HORAS
        ,RA4.RA4_DATAIN
        ,RA4.RA4_DATAFI
        ,RA1.RA1_CATEG
        ,AIQ.AIQ_DESCRI
        ,(CASE RA4.RA4_UMODAL WHEN '1' THEN 'PRESENCIAL' ELSE 'ONLINE' END) AS RA4_UMODAL
        ,(CASE RA4.RA4_UAVREC WHEN '1' THEN 'SIM' ELSE 'NAO' END) AS RA4_UAVREC
        ,(CASE RA4.RA4_EFICSN WHEN 'S' THEN 'SIM' ELSE 'NAO' END) AS RA4_EFICSN
        ,RD0.RD0_CODIGO
        ,RD0.RD0_NOME
    FROM %table:SRA% SRA
    LEFT JOIN %table:RA4% RA4 ON (SRA.RA_FILIAL=RA4.RA4_FILIAL AND SRA.RA_MAT=RA4.RA4_MAT)
    LEFT JOIN %table:RA1% RA1 ON (RA4.RA4_CURSO=RA1.RA1_CURSO)
    LEFT JOIN %table:AIQ% AIQ ON (RA1.RA1_CATEG=AIQ.AIQ_CODIGO)
    LEFT JOIN %table:RA0% RA0 ON (RA4.RA4_ENTIDA=RA0.RA0_ENTIDA)
    LEFT JOIN %table:SRJ% SRJ ON (SRA.RA_CODFUNC=SRJ.RJ_FUNCAO)
    LEFT JOIN %table:CTT% CTT ON (SRA.RA_CC=CTT.CTT_CUSTO)
    LEFT JOIN %table:RD0% RD0 ON (RA4.RA4_ULIDER=RD0.RD0_CODIGO)
    WHERE (1=1)
    AND SRA.%notDel%
    AND RA4.%notDel%
    AND RA1.%notDel%
    AND AIQ.%notDel%
    AND RA0.%notDel%
    AND SRJ.%notDel%
    AND RD0.%notDel%
    AND SRA.RA_FILIAL BETWEEN %exp:cFilialDe% AND %exp:cFilialAte%
    AND SRA.RA_MAT BETWEEN %exp:cMatriculaDe% AND %exp:cMatriculaAte%
    AND RA4.RA4_CURSO BETWEEN %exp:cCursoDe% AND %exp:cCursoAte%
    AND RA4.RA4_DATAIN BETWEEN %exp:cDataDe% AND %exp:cDataAte%
    AND RA4.RA4_ULIDER BETWEEN %exp:cLiderancaDe% AND %exp:cLiderancaAte% 
    AND (
        CASE WHEN (%exp:cTipo%='*') 
            THEN 
                1
            ELSE 
                (
                CASE WHEN (RA1.RA1_CATEG=%exp:cTipo%)
                    THEN 1 
                    ELSE 0 
                END
                )
        END
    )=1
    AND RA4.RA4_FILIAL=SRA.RA_FILIAL
    AND RA1.RA1_FILIAL=(CASE RA1.RA1_FILIAL WHEN '  ' THEN '  ' ELSE %exp:cSQLSubstr%(SRA.RA_FILIAL,1,%exp:cSQLLen%(RA1.RA1_FILIAL)) END)
    AND AIQ.AIQ_FILIAL=(CASE AIQ.AIQ_FILIAL WHEN '  ' THEN '  ' ELSE %exp:cSQLSubstr%(SRA.RA_FILIAL,1,%exp:cSQLLen%(AIQ.AIQ_FILIAL)) END)
    AND RA0.RA0_FILIAL=(CASE RA0.RA0_FILIAL WHEN '  ' THEN '  ' ELSE %exp:cSQLSubstr%(SRA.RA_FILIAL,1,%exp:cSQLLen%(RA0.RA0_FILIAL)) END)
    AND SRJ.RJ_FILIAL=(CASE SRJ.RJ_FILIAL WHEN '  ' THEN '  ' ELSE %exp:cSQLSubstr%(SRA.RA_FILIAL,1,%exp:cSQLLen%(SRJ.RJ_FILIAL)) END)
    AND CTT.CTT_FILIAL=(CASE CTT.CTT_FILIAL WHEN '  ' THEN '  ' ELSE %exp:cSQLSubstr%(SRA.RA_FILIAL,1,%exp:cSQLLen%(CTT.CTT_FILIAL)) END)
    AND RD0.RD0_FILIAL=(CASE RD0.RD0_FILIAL WHEN '  ' THEN '  ' ELSE %exp:cSQLSubstr%(SRA.RA_FILIAL,1,%exp:cSQLLen%(RD0.RD0_FILIAL)) END)
    AND SRA.RA_MAT=RA4.RA4_MAT 
    AND RA4.RA4_CURSO=RA1.RA1_CURSO
    AND RA1.RA1_CATEG=AIQ.AIQ_CODIGO
    AND RA4.RA4_ENTIDA=RA0.RA0_ENTIDA
    AND SRA.RA_CODFUNC=SRJ.RJ_FUNCAO
    AND SRA.RA_CC=CTT.CTT_CUSTO
    AND RA4.RA4_ULIDER=RD0.RD0_CODIGO
ORDER BY SRA.RA_FILIAL
        ,SRA.RA_CC
        ,CTT.CTT_DESC01
        ,SRA.RA_MAT
        ,SRA.RA_NOME
        ,SRA.RA_CODFUNC
        ,SRJ.RJ_DESC
        ,RA4.RA4_CURSO
        ,RA1.RA1_DESC
        ,RA4.RA4_ENTIDA
        ,RA0.RA0_DESC
        ,RA4.RA4_DATAIN 
        ,RD0.RD0_FILIAL
        ,RD0.RD0_CODIGO
        
        endSQL

        lQueryView:=(cTmpAlias)->(!bof().and.!eof())

    end sequence

return(lQueryView)

static function QueryViewCentroDeCustoSintetico(oTHMPergunte,cTmpAlias) as logical

    local cFilialDe as character
    local cFilialAte as character

    local cMatriculaDe as character
    local cMatriculaAte as character

    local cCursoDe as character
    local cCursoAte as character

    local cDataDe as character
    local cDataAte as character

    local cLiderancaDe as character
    local cLiderancaAte as character

    local cTipo as character

    local cTCGetDB:=TCGetDB() as character
    local cSQLLen as character
    local cSQLSubstr as character

    local lQueryView:=.F. as logical

    begin sequence 

        lQueryView:=oTHMPergunte:Get("FilialDe",@cFilialDe)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("FilialAte",@cFilialAte)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("MatriculaDe",@cMatriculaDe)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("MatriculaAte",@cMatriculaAte)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("CursoDe",@cCursoDe)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("CursoAte",@cCursoAte)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("DataDe",@cDataDe)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("DataAte",@cDataAte)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("LiderancaDe",@cLiderancaDe)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("LiderancaAte",@cLiderancaAte)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("Tipo",@cTipo)
        if (!lQueryView)
            break
        endif

        if ("*"$cTipo)
            cTipo:="*"
        endif

        cSQLLen:=if(cTCGetDB=="ORACLE","LENGTH","LEN")
        cSQLLen:="%"+cSQLLen+"%"
        
        cSQLSubstr:=if(cTCGetDB=="ORACLE","SUBSTR","SUBSTRING")
        cSQLSubstr:="%"+cSQLSubstr+"%"

        cTmpAlias:=getNextAlias()
        beginSQL alias cTmpAlias

            %noParser%

            column RA4_DATAIN as Date
            column RA4_DATAFI as Date

    SELECT SRA.RA_FILIAL
        ,SRA.RA_CC
        ,CTT.CTT_DESC01
        ,RA4.RA4_CURSO
        ,RA1.RA1_DESC
        ,RA4.RA4_ENTIDA
        ,RA0.RA0_DESC
        ,RA1.RA1_HORAS
        ,RA4.RA4_DATAIN
        ,RA1.RA1_CATEG
        ,AIQ.AIQ_DESCRI
        ,(CASE RA4.RA4_UMODAL WHEN '1' THEN 'PRESENCIAL' ELSE 'ONLINE' END) AS RA4_UMODAL
        ,(CASE RA4.RA4_UAVREC WHEN '1' THEN 'SIM' ELSE 'NAO' END) AS RA4_UAVREC
        ,(CASE RA4.RA4_EFICSN WHEN 'S' THEN 'SIM' ELSE 'NAO' END) AS RA4_EFICSN
        ,SUM((
                CASE RA4.RA4_HORAS 
                    WHEN 0 THEN (
                        CASE RA4.RA4_UNDURA 
                            WHEN 'H' THEN RA4.RA4_DURACA
                            WHEN 'D' THEN (RA4.RA4_DURACA*7.33)
                            WHEN 'S' THEN ((RA4.RA4_DURACA*5)*7.33)
                            WHEN 'M' THEN ((RA4.RA4_DURACA*30)*7.33) 
                            WHEN 'A' THEN (((RA4.RA4_DURACA*12)*30)*7.33) 
                        ELSE RA4.RA4_DURACA 
                        END) 
                    ELSE RA4.RA4_HORAS 
                END)
        ) AS RA4_HORAS
        ,COUNT(*) AS QTDPTREINO
    FROM %table:SRA% SRA
    LEFT JOIN %table:RA4% RA4 ON (SRA.RA_FILIAL=RA4.RA4_FILIAL AND SRA.RA_MAT=RA4.RA4_MAT)
    LEFT JOIN %table:RA1% RA1 ON (RA4.RA4_CURSO=RA1.RA1_CURSO)
    LEFT JOIN %table:AIQ% AIQ ON (RA1.RA1_CATEG=AIQ.AIQ_CODIGO)
    LEFT JOIN %table:RA0% RA0 ON (RA4.RA4_ENTIDA=RA0.RA0_ENTIDA)
    LEFT JOIN %table:SRJ% SRJ ON (SRA.RA_CODFUNC=SRJ.RJ_FUNCAO)
    LEFT JOIN %table:CTT% CTT ON (SRA.RA_CC=CTT.CTT_CUSTO)
    LEFT JOIN %table:RD0% RD0 ON (RA4.RA4_ULIDER=RD0.RD0_CODIGO)
    WHERE (1=1)
    AND SRA.%notDel%
    AND RA4.%notDel%
    AND RA1.%notDel%
    AND AIQ.%notDel%
    AND RA0.%notDel%
    AND SRJ.%notDel%
    AND RD0.%notDel%
    AND SRA.RA_FILIAL BETWEEN %exp:cFilialDe% AND %exp:cFilialAte%
    AND SRA.RA_MAT BETWEEN %exp:cMatriculaDe% AND %exp:cMatriculaAte%
    AND RA4.RA4_CURSO BETWEEN %exp:cCursoDe% AND %exp:cCursoAte%
    AND RA4.RA4_DATAIN BETWEEN %exp:cDataDe% AND %exp:cDataAte%
    AND RA4.RA4_ULIDER BETWEEN %exp:cLiderancaDe% AND %exp:cLiderancaAte%
    AND (
        CASE WHEN (%exp:cTipo%='*') 
            THEN 
                1
            ELSE 
                (
                CASE WHEN (RA1.RA1_CATEG=%exp:cTipo%)
                    THEN 1 
                    ELSE 0 
                END
                )
        END
    )=1
    AND RA4.RA4_FILIAL=SRA.RA_FILIAL
    AND RA1.RA1_FILIAL=(CASE RA1.RA1_FILIAL WHEN '  ' THEN '  ' ELSE %exp:cSQLSubstr%(SRA.RA_FILIAL,1,%exp:cSQLLen%(RA1.RA1_FILIAL)) END)
    AND AIQ.AIQ_FILIAL=(CASE AIQ.AIQ_FILIAL WHEN '  ' THEN '  ' ELSE %exp:cSQLSubstr%(SRA.RA_FILIAL,1,%exp:cSQLLen%(AIQ.AIQ_FILIAL)) END)
    AND RA0.RA0_FILIAL=(CASE RA0.RA0_FILIAL WHEN '  ' THEN '  ' ELSE %exp:cSQLSubstr%(SRA.RA_FILIAL,1,%exp:cSQLLen%(RA0.RA0_FILIAL)) END)
    AND SRJ.RJ_FILIAL=(CASE SRJ.RJ_FILIAL WHEN '  ' THEN '  ' ELSE %exp:cSQLSubstr%(SRA.RA_FILIAL,1,%exp:cSQLLen%(SRJ.RJ_FILIAL)) END)
    AND CTT.CTT_FILIAL=(CASE CTT.CTT_FILIAL WHEN '  ' THEN '  ' ELSE %exp:cSQLSubstr%(SRA.RA_FILIAL,1,%exp:cSQLLen%(CTT.CTT_FILIAL)) END)
    AND RD0.RD0_FILIAL=(CASE RD0.RD0_FILIAL WHEN '  ' THEN '  ' ELSE %exp:cSQLSubstr%(SRA.RA_FILIAL,1,%exp:cSQLLen%(RD0.RD0_FILIAL)) END)
    AND SRA.RA_MAT=RA4.RA4_MAT 
    AND RA4.RA4_CURSO=RA1.RA1_CURSO
    AND RA1.RA1_CATEG=AIQ.AIQ_CODIGO
    AND RA4.RA4_ENTIDA=RA0.RA0_ENTIDA
    AND SRA.RA_CODFUNC=SRJ.RJ_FUNCAO
    AND SRA.RA_CC=CTT.CTT_CUSTO
    AND RA4.RA4_ULIDER=RD0.RD0_CODIGO
GROUP BY SRA.RA_FILIAL
        ,SRA.RA_CC
        ,CTT.CTT_DESC01
        ,RA4.RA4_CURSO
        ,RA1.RA1_DESC
        ,RA4.RA4_ENTIDA
        ,RA0.RA0_DESC
        ,RA1.RA1_HORAS
        ,RA4.RA4_DATAIN
        ,RA1.RA1_CATEG
        ,AIQ.AIQ_DESCRI
        ,RA4.RA4_UMODAL
        ,RA4.RA4_UAVREC
        ,RA4.RA4_EFICSN    
ORDER BY SRA.RA_FILIAL
        ,SRA.RA_CC
        ,CTT.CTT_DESC01
        ,RA4.RA4_CURSO
        ,RA1.RA1_DESC
        ,RA4.RA4_ENTIDA
        ,RA0.RA0_DESC
        ,RA1.RA1_HORAS
        ,RA4.RA4_DATAIN
        ,RA1.RA1_CATEG
        ,AIQ.AIQ_DESCRI
        ,RA4.RA4_UMODAL
        ,RA4.RA4_UAVREC
        ,RA4.RA4_EFICSN
        
        endSQL

        lQueryView:=(cTmpAlias)->(!bof().and.!eof())

    end sequence

return(lQueryView)

static function QueryViewFilialSintetico(oTHMPergunte,cTmpAlias) as logical

    local cFilialDe as character
    local cFilialAte as character

    local cMatriculaDe as character
    local cMatriculaAte as character

    local cCursoDe as character
    local cCursoAte as character

    local cDataDe as character
    local cDataAte as character

    local cLiderancaDe as character
    local cLiderancaAte as character

    local cTipo as character

    local cTCGetDB:=TCGetDB() as character
    local cSQLLen as character
    local cSQLSubstr as character

    local lQueryView:=.F. as logical

    begin sequence 

        lQueryView:=oTHMPergunte:Get("FilialDe",@cFilialDe)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("FilialAte",@cFilialAte)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("MatriculaDe",@cMatriculaDe)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("MatriculaAte",@cMatriculaAte)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("CursoDe",@cCursoDe)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("CursoAte",@cCursoAte)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("DataDe",@cDataDe)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("DataAte",@cDataAte)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("LiderancaDe",@cLiderancaDe)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("LiderancaAte",@cLiderancaAte)
        if (!lQueryView)
            break
        endif

        lQueryView:=oTHMPergunte:Get("Tipo",@cTipo)
        if (!lQueryView)
            break
        endif

        if ("*"$cTipo)
            cTipo:="*"
        endif

        cSQLLen:=if(cTCGetDB=="ORACLE","LENGTH","LEN")
        cSQLLen:="%"+cSQLLen+"%"
        
        cSQLSubstr:=if(cTCGetDB=="ORACLE","SUBSTR","SUBSTRING")
        cSQLSubstr:="%"+cSQLSubstr+"%"

        cTmpAlias:=getNextAlias()
        beginSQL alias cTmpAlias

            %noParser%

            column RA4_DATAIN as Date
            column RA4_DATAFI as Date

    SELECT SRA.RA_FILIAL
        ,RA4.RA4_CURSO
        ,RA1.RA1_DESC
        ,RA4.RA4_ENTIDA
        ,RA0.RA0_DESC
        ,RA1.RA1_HORAS
        ,RA4.RA4_DATAIN
        ,RA1.RA1_CATEG
        ,AIQ.AIQ_DESCRI
        ,(CASE RA4.RA4_UMODAL WHEN '1' THEN 'PRESENCIAL' ELSE 'ONLINE' END) AS RA4_UMODAL
        ,(CASE RA4.RA4_UAVREC WHEN '1' THEN 'SIM' ELSE 'NAO' END) AS RA4_UAVREC
        ,(CASE RA4.RA4_EFICSN WHEN 'S' THEN 'SIM' ELSE 'NAO' END) AS RA4_EFICSN
        ,SUM((
                CASE RA4.RA4_HORAS 
                    WHEN 0 THEN (
                        CASE RA4.RA4_UNDURA 
                            WHEN 'H' THEN RA4.RA4_DURACA
                            WHEN 'D' THEN (RA4.RA4_DURACA*7.33)
                            WHEN 'S' THEN ((RA4.RA4_DURACA*5)*7.33)
                            WHEN 'M' THEN ((RA4.RA4_DURACA*30)*7.33) 
                            WHEN 'A' THEN (((RA4.RA4_DURACA*12)*30)*7.33) 
                        ELSE RA4.RA4_DURACA 
                        END) 
                    ELSE RA4.RA4_HORAS 
                END)
        ) AS RA4_HORAS
        ,COUNT(*) AS QTDPTREINO
    FROM %table:SRA% SRA
    LEFT JOIN %table:RA4% RA4 ON (SRA.RA_FILIAL=RA4.RA4_FILIAL AND SRA.RA_MAT=RA4.RA4_MAT)
    LEFT JOIN %table:RA1% RA1 ON (RA4.RA4_CURSO=RA1.RA1_CURSO)
    LEFT JOIN %table:AIQ% AIQ ON (RA1.RA1_CATEG=AIQ.AIQ_CODIGO)
    LEFT JOIN %table:RA0% RA0 ON (RA4.RA4_ENTIDA=RA0.RA0_ENTIDA)
    LEFT JOIN %table:SRJ% SRJ ON (SRA.RA_CODFUNC=SRJ.RJ_FUNCAO)
    LEFT JOIN %table:CTT% CTT ON (SRA.RA_CC=CTT.CTT_CUSTO)
    LEFT JOIN %table:RD0% RD0 ON (RA4.RA4_ULIDER=RD0.RD0_CODIGO)
    WHERE (1=1)
    AND SRA.%notDel%
    AND RA4.%notDel%
    AND RA1.%notDel%
    AND AIQ.%notDel%
    AND RA0.%notDel%
    AND SRJ.%notDel%
    AND RD0.%notDel%
    AND SRA.RA_FILIAL BETWEEN %exp:cFilialDe% AND %exp:cFilialAte%
    AND SRA.RA_MAT BETWEEN %exp:cMatriculaDe% AND %exp:cMatriculaAte%
    AND RA4.RA4_CURSO BETWEEN %exp:cCursoDe% AND %exp:cCursoAte%
    AND RA4.RA4_DATAIN BETWEEN %exp:cDataDe% AND %exp:cDataAte%
    AND RA4.RA4_ULIDER BETWEEN %exp:cLiderancaDe% AND %exp:cLiderancaAte%
    AND (
        CASE WHEN (%exp:cTipo%='*') 
            THEN 
                1
            ELSE 
                (
                CASE WHEN (RA1.RA1_CATEG=%exp:cTipo%)
                    THEN 1 
                    ELSE 0 
                END
                )
        END
    )=1
    AND RA4.RA4_FILIAL=SRA.RA_FILIAL
    AND RA1.RA1_FILIAL=(CASE RA1.RA1_FILIAL WHEN '  ' THEN '  ' ELSE %exp:cSQLSubstr%(SRA.RA_FILIAL,1,%exp:cSQLLen%(RA1.RA1_FILIAL)) END)
    AND AIQ.AIQ_FILIAL=(CASE AIQ.AIQ_FILIAL WHEN '  ' THEN '  ' ELSE %exp:cSQLSubstr%(SRA.RA_FILIAL,1,%exp:cSQLLen%(AIQ.AIQ_FILIAL)) END)
    AND RA0.RA0_FILIAL=(CASE RA0.RA0_FILIAL WHEN '  ' THEN '  ' ELSE %exp:cSQLSubstr%(SRA.RA_FILIAL,1,%exp:cSQLLen%(RA0.RA0_FILIAL)) END)
    AND SRJ.RJ_FILIAL=(CASE SRJ.RJ_FILIAL WHEN '  ' THEN '  ' ELSE %exp:cSQLSubstr%(SRA.RA_FILIAL,1,%exp:cSQLLen%(SRJ.RJ_FILIAL)) END)
    AND CTT.CTT_FILIAL=(CASE CTT.CTT_FILIAL WHEN '  ' THEN '  ' ELSE %exp:cSQLSubstr%(SRA.RA_FILIAL,1,%exp:cSQLLen%(CTT.CTT_FILIAL)) END)
    AND RD0.RD0_FILIAL=(CASE RD0.RD0_FILIAL WHEN '  ' THEN '  ' ELSE %exp:cSQLSubstr%(SRA.RA_FILIAL,1,%exp:cSQLLen%(RD0.RD0_FILIAL)) END)
    AND SRA.RA_MAT=RA4.RA4_MAT 
    AND RA4.RA4_CURSO=RA1.RA1_CURSO
    AND RA1.RA1_CATEG=AIQ.AIQ_CODIGO
    AND RA4.RA4_ENTIDA=RA0.RA0_ENTIDA
    AND SRA.RA_CODFUNC=SRJ.RJ_FUNCAO
    AND SRA.RA_CC=CTT.CTT_CUSTO
    AND RA4.RA4_ULIDER=RD0.RD0_CODIGO
GROUP BY SRA.RA_FILIAL
        ,RA4.RA4_CURSO
        ,RA1.RA1_DESC
        ,RA4.RA4_ENTIDA
        ,RA0.RA0_DESC
        ,RA1.RA1_HORAS
        ,RA4.RA4_DATAIN
        ,RA1.RA1_CATEG
        ,AIQ.AIQ_DESCRI
        ,RA4.RA4_UMODAL
        ,RA4.RA4_UAVREC
        ,RA4.RA4_EFICSN    
ORDER BY SRA.RA_FILIAL
        ,RA4.RA4_CURSO
        ,RA1.RA1_DESC
        ,RA4.RA4_ENTIDA
        ,RA0.RA0_DESC
        ,RA1.RA1_HORAS
        ,RA4.RA4_DATAIN
        ,RA1.RA1_CATEG
        ,AIQ.AIQ_DESCRI
        ,RA4.RA4_UMODAL
        ,RA4.RA4_UAVREC
        ,RA4.RA4_EFICSN
        
        endSQL

        lQueryView:=(cTmpAlias)->(!bof().and.!eof())

    end sequence

return(lQueryView)

static function Pergunte(oTHMPergunte as object) as logical
    
    local aPBoxPrm:=Array(0) as array
    local aPBoxRet:=Array(0) as array

    local cPBoxTit:=OemToAnsi("Informe os parametros") as character

    local lParamBox:=.F. as logical

    local nPBox as numeric

    saveInter()

        aAdd(aPBoxPrm,Array(9))
        nPBox:=Len(aPBoxPrm)
        //01----------------------------------------------------------------------------------------------
        aPBoxPrm[nPBox][1]:=1 //[1]:1 - MsGet
        aPBoxPrm[nPBox][2]:="Filial.De" //[2]:Descricao
        aPBoxPrm[nPBox][3]:=Space(GetSX3Cache("RA_FILIAL","X3_TAMANHO")) //[3]:String contendo o inicializador do campo
        aPBoxPrm[nPBox][4]:="@" //[4]:String contendo a Picture do campo
        aPBoxPrm[nPBox][5]:="allWaysTrue()" //[5]:String contendo a validacao
        aPBoxPrm[nPBox][6]:="SM0" //[6]:Consulta F3
        aPBoxPrm[nPBox][7]:="AllWaysTrue()" //[7]:String contendo a validacao When
        aPBoxPrm[nPBox][8]:=CalcFieldSize(valType(aPBoxPrm[nPBox][3]),GetSX3Cache("RA_FILIAL","X3_TAMANHO"),0,aPBoxPrm[nPBox][4],aPBoxPrm[nPBox][2]) //[8]:Tamanho do MsGet
        aPBoxPrm[nPBox][9]:=.F. //[9]:Flag .T./.F. Parametro Obrigatorio ?

        aAdd(aPBoxPrm,Array(9))
        nPBox:=Len(aPBoxPrm)
        //02----------------------------------------------------------------------------------------------
        aPBoxPrm[nPBox][1]:=1 //[1]:1 - MsGet
        aPBoxPrm[nPBox][2]:="Filial.Ate" //[2]:Descricao
        aPBoxPrm[nPBox][3]:=Space(GetSX3Cache("RA_FILIAL","X3_TAMANHO")) //[3]:String contendo o inicializador do campo
        aPBoxPrm[nPBox][4]:="@" //[4]:String contendo a Picture do campo
        aPBoxPrm[nPBox][5]:="NaoVazio()" //[5]:String contendo a validacao
        aPBoxPrm[nPBox][6]:="SM0" //[6]:Consulta F3
        aPBoxPrm[nPBox][7]:="AllWaysTrue()" //[7]:String contendo a validacao When
        aPBoxPrm[nPBox][8]:=CalcFieldSize(valType(aPBoxPrm[nPBox][3]),GetSX3Cache("RA_FILIAL","X3_TAMANHO"),0,aPBoxPrm[nPBox][4],aPBoxPrm[nPBox][2]) //[8]:Tamanho do MsGet
        aPBoxPrm[nPBox][9]:=.F. //[9]:Flag .T./.F. Parametro Obrigatorio ?

        aAdd(aPBoxPrm,Array(9))
        nPBox:=Len(aPBoxPrm)
        //03----------------------------------------------------------------------------------------------
        aPBoxPrm[nPBox][1]:=1 //[1]:1 - MsGet
        aPBoxPrm[nPBox][2]:="Matricula.De" //[2]:Descricao
        aPBoxPrm[nPBox][3]:=Space(GetSX3Cache("RA_MAT","X3_TAMANHO")) //[3]:String contendo o inicializador do campo
        aPBoxPrm[nPBox][4]:="@" //[4]:String contendo a Picture do campo
        aPBoxPrm[nPBox][5]:="AllWaysTrue()" //[5]:String contendo a validacao
        aPBoxPrm[nPBox][6]:="SRA" //[6]:Consulta F3
        aPBoxPrm[nPBox][7]:="AllWaysTrue()" //[7]:String contendo a validacao When
        aPBoxPrm[nPBox][8]:=CalcFieldSize(valType(aPBoxPrm[nPBox][3]),GetSX3Cache("RA_MAT","X3_TAMANHO"),0,aPBoxPrm[nPBox][4],aPBoxPrm[nPBox][2]) //[8]:Tamanho do MsGet
        aPBoxPrm[nPBox][9]:=.F. //[9]:Flag .T./.F. Parametro Obrigatorio ?

        aAdd(aPBoxPrm,Array(9))
        nPBox:=Len(aPBoxPrm)
        //04----------------------------------------------------------------------------------------------
        aPBoxPrm[nPBox][1]:=1 //[1]:1 - MsGet
        aPBoxPrm[nPBox][2]:="Matricula.Ate" //[2]:Descricao
        aPBoxPrm[nPBox][3]:=Space(GetSX3Cache("RA_MAT","X3_TAMANHO")) //[3]:String contendo o inicializador do campo
        aPBoxPrm[nPBox][4]:="@" //[4]:String contendo a Picture do campo
        aPBoxPrm[nPBox][5]:="NaoVazio()" //[5]:String contendo a validacao
        aPBoxPrm[nPBox][6]:="SRA" //[6]:Consulta F3
        aPBoxPrm[nPBox][7]:="AllWaysTrue()" //[7]:String contendo a validacao When
        aPBoxPrm[nPBox][8]:=CalcFieldSize(valType(aPBoxPrm[nPBox][3]),GetSX3Cache("RA_MAT","X3_TAMANHO"),0,aPBoxPrm[nPBox][4],aPBoxPrm[nPBox][2]) //[8]:Tamanho do MsGet
        aPBoxPrm[nPBox][9]:=.F. //[9]:Flag .T./.F. Parametro Obrigatorio ?

        aAdd(aPBoxPrm,Array(9))
        nPBox:=Len(aPBoxPrm)
        //05----------------------------------------------------------------------------------------------
        aPBoxPrm[nPBox][1]:=1 //[1]:1 - MsGet
        aPBoxPrm[nPBox][2]:="Curso.De" //[2]:Descricao
        aPBoxPrm[nPBox][3]:=Space(GetSX3Cache("RA1_CURSO","X3_TAMANHO")) //[3]:String contendo o inicializador do campo
        aPBoxPrm[nPBox][4]:="@" //[4]:String contendo a Picture do campo
        aPBoxPrm[nPBox][5]:="AllWaysTrue()" //[5]:String contendo a validacao
        aPBoxPrm[nPBox][6]:="RA1" //[6]:Consulta F3
        aPBoxPrm[nPBox][7]:="AllWaysTrue()" //[7]:String contendo a validacao When
        aPBoxPrm[nPBox][8]:=CalcFieldSize(valType(aPBoxPrm[nPBox][3]),GetSX3Cache("RA1_CURSO","X3_TAMANHO"),0,aPBoxPrm[nPBox][4],aPBoxPrm[nPBox][2]) //[8]:Tamanho do MsGet
        aPBoxPrm[nPBox][9]:=.F. //[9]:Flag .T./.F. Parametro Obrigatorio ?

        aAdd(aPBoxPrm,Array(9))
        nPBox:=Len(aPBoxPrm)
        //06----------------------------------------------------------------------------------------------
        aPBoxPrm[nPBox][1]:=1 //[1]:1 - MsGet
        aPBoxPrm[nPBox][2]:="Curso.Ate" //[2]:Descricao
        aPBoxPrm[nPBox][3]:=Space(GetSX3Cache("RA1_CURSO","X3_TAMANHO")) //[3]:String contendo o inicializador do campo
        aPBoxPrm[nPBox][4]:="@" //[4]:String contendo a Picture do campo
        aPBoxPrm[nPBox][5]:="NaoVazio()" //[5]:String contendo a validacao
        aPBoxPrm[nPBox][6]:="RA1" //[6]:Consulta F3
        aPBoxPrm[nPBox][7]:="AllWaysTrue()" //[7]:String contendo a validacao When
        aPBoxPrm[nPBox][8]:=CalcFieldSize(valType(aPBoxPrm[nPBox][3]),GetSX3Cache("RA1_CURSO","X3_TAMANHO"),0,aPBoxPrm[nPBox][4],aPBoxPrm[nPBox][2]) //[8]:Tamanho do MsGet
        aPBoxPrm[nPBox][9]:=.F. //[9]:Flag .T./.F. Parametro Obrigatorio ?        

        aAdd(aPBoxPrm,Array(9))
        nPBox:=Len(aPBoxPrm)
        //07----------------------------------------------------------------------------------------------
        aPBoxPrm[nPBox][1]:=1 //[1]:1 - MsGet
        aPBoxPrm[nPBox][2]:="Data.De" //[2]:Descricao
        aPBoxPrm[nPBox][3]:=CToD("") //[3]:String contendo o inicializador do campo
        aPBoxPrm[nPBox][4]:="@D" //[4]:String contendo a Picture do campo
        aPBoxPrm[nPBox][5]:="AllWaysTrue()" //[5]:String contendo a validacao
        aPBoxPrm[nPBox][6]:="" //[6]:Consulta F3
        aPBoxPrm[nPBox][7]:="AllWaysTrue()" //[7]:String contendo a validacao When
        aPBoxPrm[nPBox][8]:=CalcFieldSize(valType(aPBoxPrm[nPBox][3]),GetSX3Cache("RA4_DATAIN","X3_TAMANHO"),0,aPBoxPrm[nPBox][4],aPBoxPrm[nPBox][2])+10 //[8]:Tamanho do MsGet
        aPBoxPrm[nPBox][9]:=.F. //[9]:Flag .T./.F. Parametro Obrigatorio ?

        aAdd(aPBoxPrm,Array(9))
        nPBox:=Len(aPBoxPrm)
        //08----------------------------------------------------------------------------------------------
        aPBoxPrm[nPBox][1]:=1 //[1]:1 - MsGet
        aPBoxPrm[nPBox][2]:="Data.Ate" //[2]:Descricao
        aPBoxPrm[nPBox][3]:=CToD("") //[3]:String contendo o inicializador do campo
        aPBoxPrm[nPBox][4]:="@D" //[4]:String contendo a Picture do campo
        aPBoxPrm[nPBox][5]:="NaoVazio()" //[5]:String contendo a validacao
        aPBoxPrm[nPBox][6]:="" //[6]:Consulta F3
        aPBoxPrm[nPBox][7]:="AllWaysTrue()" //[7]:String contendo a validacao When
        aPBoxPrm[nPBox][8]:=CalcFieldSize(valType(aPBoxPrm[nPBox][3]),GetSX3Cache("RA4_DATAIN","X3_TAMANHO"),0,aPBoxPrm[nPBox][4],aPBoxPrm[nPBox][2])+10 //[8]:Tamanho do MsGet
        aPBoxPrm[nPBox][9]:=.F. //[9]:Flag .T./.F. Parametro Obrigatorio ?        

        aAdd(aPBoxPrm,Array(9))
        nPBox:=Len(aPBoxPrm)
        //09----------------------------------------------------------------------------------------------
        aPBoxPrm[nPBox][1]:=1 //[1]:1 - MsGet
        aPBoxPrm[nPBox][2]:="Lideranca.De" //[2]:Descricao
        aPBoxPrm[nPBox][3]:=Space(GetSX3Cache("RA4_ULIDER","X3_TAMANHO")) //[3]:String contendo o inicializador do campo
        aPBoxPrm[nPBox][4]:="@!" //[4]:String contendo a Picture do campo
        aPBoxPrm[nPBox][5]:="AllWaysTrue()" //[5]:String contendo a validacao
        aPBoxPrm[nPBox][6]:="RD0" //[6]:Consulta F3
        aPBoxPrm[nPBox][7]:="AllWaysTrue()" //[7]:String contendo a validacao When
        aPBoxPrm[nPBox][8]:=CalcFieldSize(valType(aPBoxPrm[nPBox][3]),GetSX3Cache("RA4_ULIDER","X3_TAMANHO"),0,aPBoxPrm[nPBox][4],aPBoxPrm[nPBox][2]) //[8]:Tamanho do MsGet
        aPBoxPrm[nPBox][9]:=.F. //[9]:Flag .T./.F. Parametro Obrigatorio ?

        aAdd(aPBoxPrm,Array(9))
        nPBox:=Len(aPBoxPrm)
        //10----------------------------------------------------------------------------------------------
        aPBoxPrm[nPBox][1]:=1 //[1]:1 - MsGet
        aPBoxPrm[nPBox][2]:="Lideranca.Ate" //[2]:Descricao
        aPBoxPrm[nPBox][3]:=Space(GetSX3Cache("RA4_ULIDER","X3_TAMANHO")) //[3]:String contendo o inicializador do campo
        aPBoxPrm[nPBox][4]:="@!" //[4]:String contendo a Picture do campo
        aPBoxPrm[nPBox][5]:="NaoVazio()" //[5]:String contendo a validacao
        aPBoxPrm[nPBox][6]:="SRA" //[6]:Consulta F3
        aPBoxPrm[nPBox][7]:="AllWaysTrue()" //[7]:String contendo a validacao When
        aPBoxPrm[nPBox][8]:=CalcFieldSize(valType(aPBoxPrm[nPBox][3]),GetSX3Cache("RA4_ULIDER","X3_TAMANHO"),0,aPBoxPrm[nPBox][4],aPBoxPrm[nPBox][2]) //[8]:Tamanho do MsGet
        aPBoxPrm[nPBox][9]:=.F. //[9]:Flag .T./.F. Parametro Obrigatorio ?  

        aAdd(aPBoxPrm,Array(9))
        nPBox:=Len(aPBoxPrm)
        //11----------------------------------------------------------------------------------------------
        aPBoxPrm[nPBox][1]:=1 //[1]:1 - MsGet
        aPBoxPrm[nPBox][2]:="Tipo" //[2]:Descricao
        aPBoxPrm[nPBox][3]:=Space(GetSX3Cache("AIQ_CODIGO","X3_TAMANHO")) //[3]:String contendo o inicializador do campo
        aPBoxPrm[nPBox][4]:="@!" //[4]:String contendo a Picture do campo
        aPBoxPrm[nPBox][5]:="NaoVazio()" //[5]:String contendo a validacao
        aPBoxPrm[nPBox][6]:="AIQ" //[6]:Consulta F3
        aPBoxPrm[nPBox][7]:="AllWaysTrue()" //[7]:String contendo a validacao When
        aPBoxPrm[nPBox][8]:=CalcFieldSize(valType(aPBoxPrm[nPBox][3]),GetSX3Cache("AIQ_CODIGO","X3_TAMANHO"),0,aPBoxPrm[nPBox][4],aPBoxPrm[nPBox][2]) //[8]:Tamanho do MsGet
        aPBoxPrm[nPBox][9]:=.T. //[9]:Flag .T./.F. Parametro Obrigatorio ?  

        aAdd(aPBoxPrm,Array(7))
        nPBox:=Len(aPBoxPrm)
        //12----------------------------------------------------------------------------------------------
        aPBoxPrm[nPBox][1]:=3 // Tipo 3 -> Radio
        aPBoxPrm[nPBox][2]:="Tipo.Relatorio" //[2]:Descricao
        aPBoxPrm[nPBox][3]:=1 //[3]:Numerico contendo a opcao inicial do Radio
        aPBoxPrm[nPBox][4]:={OemToAnsi("Analitico"),OemToAnsi("Sintetico")} //[4]:Array contendo as opcoes do Radio
        aPBoxPrm[nPBox][5]:=100 //[5]:Tamanho do Radio
        aPBoxPrm[nPBox][6]:="AllWaysTrue()" //[6]:Validacao
        aPBoxPrm[nPBox][7]:=.F. //[9]:Flag .T./.F. Parametro Obrigatorio ?  

        aAdd(aPBoxPrm,Array(7))
        nPBox:=Len(aPBoxPrm)
        //12----------------------------------------------------------------------------------------------
        aPBoxPrm[nPBox][1]:=3 // Tipo 3 -> Radio
        aPBoxPrm[nPBox][2]:="Sintetiza.Por" //[2]:Descricao
        aPBoxPrm[nPBox][3]:=1 //[3]:Numerico contendo a opcao inicial do Radio
        aPBoxPrm[nPBox][4]:={"Filial","Centro de Custo"} //[4]:Array contendo as opcoes do Radio
        aPBoxPrm[nPBox][5]:=100 //[5]:Tamanho do Radio
        aPBoxPrm[nPBox][6]:="AllWaysTrue()" //[6]:Validacao
        aPBoxPrm[nPBox][7]:=.F. //[9]:Flag .T./.F. Parametro Obrigatorio ?  

        while (!(lParamBox:=ParamBox(@aPBoxPrm,@cPBoxTit,@aPBoxRet,NIL,NIL,.T.,NIL,NIL,NIL,NIL,.T.,.T.)))
            lParamBox:=MsgYesNo("Deseja Abortar a Geracao?","Atencao!")
            if (lParamBox)
                lParamBox:=.F.
                exit
            endif
        end while

        if (lParamBox)
            for nPBox:=1 To Len(aPBoxPrm)
                oTHMPergunte:Set(strTran(aPBoxPrm[nPBox][2],".",""),aPBoxRet[nPBox])
            next nPBox
        endif

    restInter()

    FWFreeArray(@aPBoxRet)
    FWFreeArray(@aPBoxPrm)

return(lParamBox)
