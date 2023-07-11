#INCLUDE "protheus.ch"
#INCLUDE "apwizard.ch"

#DEFINE SIMPLES Char( 39 )
#DEFINE DUPLAS  Char( 34 )

#DEFINE CSSBOTAO	"QPushButton { color: #024670; "+;
"    border-image: url(rpo:fwstd_btn_nml.png) 3 3 3 3 stretch; "+;
"    border-top-width: 3px; "+;
"    border-left-width: 3px; "+;
"    border-right-width: 3px; "+;
"    border-bottom-width: 3px }"+;
"QPushButton:pressed {	color: #FFFFFF; "+;
"    border-image: url(rpo:fwstd_btn_prd.png) 3 3 3 3 stretch; "+;
"    border-top-width: 3px; "+;
"    border-left-width: 3px; "+;
"    border-right-width: 3px; "+;
"    border-bottom-width: 3px }"

//--------------------------------------------------------------------
/*/{Protheus.doc} UPDEXP

Função de update de dicionários para compatibilização

@author UPDATE gerado automaticamente
@since  02/05/2023
@obs    Gerado por EXPORDIC - V.7.5.2.2 EFS / Upd. V.5.3.1 EFS
@version 1.0
/*/
//--------------------------------------------------------------------
Function U_UPDInsTrm( cEmpAmb, cFilAmb )

Local   aSay      := {}
Local   aButton   := {}
Local   aMarcadas := {}
Local   cTitulo   := "ATUALIZAÇÃO DE DICIONÁRIOS E TABELAS"
Local   cDesc1    := "Esta rotina tem como função fazer  a atualização  dos dicionários do Sistema ( SX?/SIX )"
Local   cDesc2    := "Este processo deve ser executado em modo EXCLUSIVO, ou seja não podem haver outros"
Local   cDesc3    := "usuários  ou  jobs utilizando  o sistema.  É EXTREMAMENTE recomendavél  que  se  faça"
Local   cDesc4    := "um BACKUP  dos DICIONÁRIOS  e da  BASE DE DADOS antes desta atualização, para"
Local   cDesc5    := "que caso ocorram eventuais falhas, esse backup possa ser restaurado."
*Local   cDesc6    := ""
*Local   cDesc7    := ""
Local   cMsg      := ""
Local   lOk       := .F.
Local   lAuto     := ( cEmpAmb <> NIL .or. cFilAmb <> NIL )

Private oMainWnd  := NIL
Private oProcess  := NIL

#IFDEF TOP
    TCInternal( 5, "*OFF" ) // Desliga Refresh no Lock do Top
#ENDIF

__cInterNet := NIL
__lPYME     := .F.

Set Dele On

// Mensagens de Tela Inicial
aAdd( aSay, cDesc1 )
aAdd( aSay, cDesc2 )
aAdd( aSay, cDesc3 )
aAdd( aSay, cDesc4 )
aAdd( aSay, cDesc5 )
//aAdd( aSay, cDesc6 )
//aAdd( aSay, cDesc7 )

// Botoes Tela Inicial
aAdd(  aButton, {  1, .T., { || lOk := .T., FechaBatch() } } )
aAdd(  aButton, {  2, .T., { || lOk := .F., FechaBatch() } } )

If lAuto
	lOk := .T.
Else
	FormBatch(  cTitulo,  aSay,  aButton )
EndIf

If lOk

	If FindFunction( "MPDicInDB" ) .AND. MPDicInDB()
		cMsg := "Este update NÃO PODE ser executado neste Ambiente." + CRLF + CRLF + ;
				"Os arquivos de dicionários se encontram no Banco de Dados e este update está preparado " + " " + ;
				"para atualizar apenas ambientes com dicionários no formato ISAM (.dbf ou .dtc)."

		If lAuto
			AutoGrLog( Replicate( "-", 128 ) )
			AutoGrLog( Replicate( " ", 128 ) )
			AutoGrLog( "LOG DA ATUALIZAÇÃO DOS DICIONÁRIOS" )
			AutoGrLog( Replicate( " ", 128 ) )
			AutoGrLog( Replicate( "-", 128 ) )
			AutoGrLog( Replicate( " ", 128 ) )
			AutoGrLog( cMsg )
			ConOut( DToC(Date()) + "|" + Time() + cMsg )
		Else
			MsgInfo( cMsg )
		EndIf

		Return NIL
	EndIf

	If lAuto
		aMarcadas :={{ cEmpAmb, cFilAmb, "" }}
	Else

		// Validação se é administrador
		If !MyIsAdmin()
			Final( "Atualização não realizada." )
		Endif

		aMarcadas := EscEmpresa()
	EndIf

	If !Empty( aMarcadas )
		If lAuto .OR. MsgNoYes( "Confirma a atualização dos dicionários ?", cTitulo )
			oProcess := MsNewProcess():New( { | lEnd | lOk := FSTProc( @lEnd, aMarcadas, lAuto ) }, "Atualizando", "Aguarde, atualizando ...", .F. )
			oProcess:Activate()

			If lAuto
				If lOk
					MsgStop( "Atualização realizada.", "UPDEXP" )
				Else
					MsgStop( "Atualização não realizada.", "UPDEXP" )
				EndIf
				dbCloseAll()
			Else
				If lOk
					Final( "Atualização realizada." )
				Else
					Final( "Atualização não realizada." )
				EndIf
			EndIf

		Else
			Final( "Atualização não realizada." )

		EndIf

	Else
		Final( "Atualização não realizada." )

	EndIf

EndIf

Return NIL


//--------------------------------------------------------------------
/*/{Protheus.doc} FSTProc

Função de processamento da gravação dos arquivos

@author UPDATE gerado automaticamente
@since  02/05/2023
@obs    Gerado por EXPORDIC - V.7.5.2.2 EFS / Upd. V.5.3.1 EFS
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function FSTProc( lEnd, aMarcadas, lAuto )
Local   aInfo     := {}
Local   aRecnoSM0 := {}
*Local   cAux      := ""
Local   cFile     := ""
*Local   cFileLog  := ""
Local   cMask     := "Arquivos Texto" + "(*.TXT)|*.txt|"
Local   cTCBuild  := "TCGetBuild"
Local   cTexto    := ""
Local   cTopBuild := ""
Local   lOpen     := .F.
Local   lRet      := .T.
Local   nI        := 0
Local   nPos      := 0
*Local   nRecno    := 0
Local   nX        := 0
Local   oDlg      := NIL
Local   oFont     := NIL
Local   oMemo     := NIL

Private aArqUpd   := {}

If ( lOpen := MyOpenSm0(.T.) )

	dbSelectArea( "SM0" )
	dbGoTop()

	While !SM0->( EOF() )
		// Só adiciona no aRecnoSM0 se a empresa for diferente
		If aScan( aRecnoSM0, { |x| x[2] == SM0->M0_CODIGO } ) == 0 ;
		   .AND. aScan( aMarcadas, { |x| x[1] == SM0->M0_CODIGO } ) > 0
			aAdd( aRecnoSM0, { Recno(), SM0->M0_CODIGO } )
		EndIf
		SM0->( dbSkip() )
	End

	SM0->( dbCloseArea() )

	If lOpen

		For nI := 1 To Len( aRecnoSM0 )

			If !( lOpen := MyOpenSm0(.F.) )
				MsgStop( "Atualização da empresa " + aRecnoSM0[nI][2] + " não efetuada." )
				Exit
			EndIf

			SM0->( dbGoTo( aRecnoSM0[nI][1] ) )

			RpcSetEnv( SM0->M0_CODIGO, SM0->M0_CODFIL )

			lMsFinalAuto := .F.
			lMsHelpAuto  := .F.

			AutoGrLog( Replicate( "-", 128 ) )
			AutoGrLog( Replicate( " ", 128 ) )
			AutoGrLog( "LOG DA ATUALIZAÇÃO DOS DICIONÁRIOS" )
			AutoGrLog( Replicate( " ", 128 ) )
			AutoGrLog( Replicate( "-", 128 ) )
			AutoGrLog( " " )
			AutoGrLog( " Dados Ambiente" )
			AutoGrLog( " --------------------" )
			AutoGrLog( " Empresa / Filial...: " + cEmpAnt + "/" + cFilAnt )
			AutoGrLog( " Nome Empresa.......: " + Capital( AllTrim( GetAdvFVal( "SM0", "M0_NOMECOM", cEmpAnt + cFilAnt, 1, "" ) ) ) )
			AutoGrLog( " Nome Filial........: " + Capital( AllTrim( GetAdvFVal( "SM0", "M0_FILIAL" , cEmpAnt + cFilAnt, 1, "" ) ) ) )
			AutoGrLog( " DataBase...........: " + DtoC( dDataBase ) )
			AutoGrLog( " Data / Hora Ínicio.: " + DtoC( Date() )  + " / " + Time() )
			AutoGrLog( " Environment........: " + GetEnvServer()  )
			AutoGrLog( " StartPath..........: " + GetSrvProfString( "StartPath", "" ) )
			AutoGrLog( " RootPath...........: " + GetSrvProfString( "RootPath" , "" ) )
			AutoGrLog( " Versão.............: " + GetVersao(.T.) )
			AutoGrLog( " Usuário TOTVS .....: " + __cUserId + " " +  cUserName )
			AutoGrLog( " Computer Name......: " + GetComputerName() )

			aInfo   := GetUserInfo()
			If ( nPos    := aScan( aInfo,{ |x,y| x[3] == ThreadId() } ) ) > 0
				AutoGrLog( " " )
				AutoGrLog( " Dados Thread" )
				AutoGrLog( " --------------------" )
				AutoGrLog( " Usuário da Rede....: " + aInfo[nPos][1] )
				AutoGrLog( " Estação............: " + aInfo[nPos][2] )
				AutoGrLog( " Programa Inicial...: " + aInfo[nPos][5] )
				AutoGrLog( " Environment........: " + aInfo[nPos][6] )
				AutoGrLog( " Conexão............: " + AllTrim( StrTran( StrTran( aInfo[nPos][7], Chr( 13 ), "" ), Chr( 10 ), "" ) ) )
			EndIf
			AutoGrLog( Replicate( "-", 128 ) )
			AutoGrLog( " " )

			If !lAuto
				AutoGrLog( Replicate( "-", 128 ) )
				AutoGrLog( "Empresa : " + SM0->M0_CODIGO + "/" + SM0->M0_NOME + CRLF )
			EndIf

			oProcess:SetRegua1( 8 )


			oProcess:IncRegua1( "Dicionário de arquivos" + " - " + SM0->M0_CODIGO + " " + SM0->M0_NOME + " ..." )
			FSAtuSX2()


			FSAtuSX3()


			oProcess:IncRegua1( "Dicionário de índices" + " - " + SM0->M0_CODIGO + " " + SM0->M0_NOME + " ..." )
			FSAtuSIX()

			oProcess:IncRegua1( "Dicionário de dados" + " - " + SM0->M0_CODIGO + " " + SM0->M0_NOME + " ..." )
			oProcess:IncRegua2( "Atualizando campos/índices" )

			// Alteração física dos arquivos
			__SetX31Mode( .F. )

			If FindFunction(cTCBuild)
				cTopBuild := &cTCBuild.()
			EndIf

			For nX := 1 To Len( aArqUpd )

				If cTopBuild >= "20090811" .AND. TcInternal( 89 ) == "CLOB_SUPPORTED"
					If ( ( aArqUpd[nX] >= "NQ " .AND. aArqUpd[nX] <= "NZZ" ) .OR. ( aArqUpd[nX] >= "O0 " .AND. aArqUpd[nX] <= "NZZ" ) ) .AND.;
						!aArqUpd[nX] $ "NQD,NQF,NQP,NQT"
						TcInternal( 25, "CLOB" )
					EndIf
				EndIf

				If Select( aArqUpd[nX] ) > 0
					dbSelectArea( aArqUpd[nX] )
					dbCloseArea()
				EndIf

				X31UpdTable( aArqUpd[nX] )

				If __GetX31Error()
					Alert( __GetX31Trace() )
					MsgStop( "Ocorreu um erro desconhecido durante a atualização da tabela : " + aArqUpd[nX] + ". Verifique a integridade do dicionário e da tabela.", "ATENÇÃO" )
					AutoGrLog( "Ocorreu um erro desconhecido durante a atualização da estrutura da tabela : " + aArqUpd[nX] )
				EndIf

				If cTopBuild >= "20090811" .AND. TcInternal( 89 ) == "CLOB_SUPPORTED"
					TcInternal( 25, "OFF" )
				EndIf

			Next nX


			oProcess:IncRegua1( "Dicionário de parâmetros" + " - " + SM0->M0_CODIGO + " " + SM0->M0_NOME + " ..." )
			FSAtuSX6()


			oProcess:IncRegua1( "Dicionário de gatilhos" + " - " + SM0->M0_CODIGO + " " + SM0->M0_NOME + " ..." )
			FSAtuSX7()

			oProcess:IncRegua1( "Dicionário de consultas padrão" + " - " + SM0->M0_CODIGO + " " + SM0->M0_NOME + " ..." )
			FSAtuSXB()

			oProcess:IncRegua1( "Helps de Campo" + " - " + SM0->M0_CODIGO + " " + SM0->M0_NOME + " ..." )
			FSAtuHlp()

			AutoGrLog( Replicate( "-", 128 ) )
			AutoGrLog( " Data / Hora Final.: " + DtoC( Date() ) + " / " + Time() )
			AutoGrLog( Replicate( "-", 128 ) )

			RpcClearEnv()

		Next nI

		If !lAuto

			cTexto := LeLog()

			Define Font oFont Name "Mono AS" Size 5, 12

			Define MsDialog oDlg Title "Atualização concluida." From 3, 0 to 340, 417 Pixel

			@ 5, 5 Get oMemo Var cTexto Memo Size 200, 145 Of oDlg Pixel
			oMemo:bRClicked := { || AllwaysTrue() }
			oMemo:oFont     := oFont

			Define SButton From 153, 175 Type  1 Action oDlg:End() Enable Of oDlg Pixel // Apaga
			Define SButton From 153, 145 Type 13 Action ( cFile := cGetFile( cMask, "" ), If( cFile == "", .T., ;
			MemoWrite( cFile, cTexto ) ) ) Enable Of oDlg Pixel

			Activate MsDialog oDlg Center

		EndIf

	EndIf

Else

	lRet := .F.

EndIf

Return lRet


//--------------------------------------------------------------------
/*/{Protheus.doc} FSAtuSX2

Função de processamento da gravação do SX2 - Arquivos

@author UPDATE gerado automaticamente
@since  02/05/2023
@obs    Gerado por EXPORDIC - V.7.5.2.2 EFS / Upd. V.5.3.1 EFS
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function FSAtuSX2()
Local aEstrut   := {}
Local aSX2      := {}
Local cAlias    := ""
Local cCpoUpd   := "X2_ROTINA /X2_UNICO  /X2_DISPLAY/X2_SYSOBJ /X2_USROBJ /X2_POSLGT /"
Local cEmpr     := ""
Local cPath     := ""
Local nI        := 0
Local nJ        := 0

AutoGrLog( "Ínicio da Atualização" + " SX2" + CRLF )

aEstrut := { "X2_CHAVE"  , "X2_PATH"   , "X2_ARQUIVO", "X2_NOME"   , "X2_NOMESPA", "X2_NOMEENG", "X2_MODO"   , ;
             "X2_TTS"    , "X2_ROTINA" , "X2_PYME"   , "X2_UNICO"  , "X2_DISPLAY", "X2_SYSOBJ" , "X2_USROBJ" , ;
             "X2_POSLGT" , "X2_CLOB"   , "X2_AUTREC" , "X2_MODOEMP", "X2_MODOUN" , "X2_MODULO" }


dbSelectArea( "SX2" )
SX2->( dbSetOrder( 1 ) )
SX2->( dbGoTop() )
cPath := SX2->X2_PATH
cPath := IIf( Right( AllTrim( cPath ), 1 ) <> "\", PadR( AllTrim( cPath ) + "\", Len( cPath ) ), cPath )
cEmpr := Substr( SX2->X2_ARQUIVO, 4 )

aAdd( aSX2, {'RA1',cPath,'RA1'+cEmpr,'Cursos','Cursos','Courses','C','','','N','RA1_FILIAL+RA1_CURSO','RA1_CURSO+RA1_DESC','TRMA040','','1','2','2','E','E',26} )
aAdd( aSX2, {'RA4',cPath,'RA4'+cEmpr,'Cursos do Funcionário','Cursos del Empleado','Employee Courses','E','','','N','RA4_FILIAL+RA4_MAT+RA4_CALEND+RA4_CURSO+RA4_TURMA+RA4_SINONI+DTOS(RA4_DATAIN)','RA4_MAT+RA4_NOME+RA4_CURSO','','','1','2','2','E','E',26} )
aAdd( aSX2, {'RA6',cPath,'RA6'+cEmpr,'Programação Cursos Entidades','Programación Cursos Entes','Entity Course Program','C','','','N','RA6_FILIAL+RA6_CURSO+RA6_ENTIDA','','','','1','2','2','E','E',26} )
//
// Atualizando dicionário
//
oProcess:SetRegua2( Len( aSX2 ) )

dbSelectArea( "SX2" )
dbSetOrder( 1 )

For nI := 1 To Len( aSX2 )

	oProcess:IncRegua2( "Atualizando Arquivos (SX2) ..." )

	If !SX2->( dbSeek( aSX2[nI][1] ) )

		If !( aSX2[nI][1] $ cAlias )
			cAlias += aSX2[nI][1] + "/"
			AutoGrLog( "Foi incluída a tabela " + aSX2[nI][1] )
		EndIf

		RecLock( "SX2", .T. )
		For nJ := 1 To Len( aSX2[nI] )
			If FieldPos( aEstrut[nJ] ) > 0
				If AllTrim( aEstrut[nJ] ) == "X2_ARQUIVO"
					FieldPut( FieldPos( aEstrut[nJ] ), SubStr( aSX2[nI][nJ], 1, 3 ) + cEmpAnt +  "0" )
				Else
					FieldPut( FieldPos( aEstrut[nJ] ), aSX2[nI][nJ] )
				EndIf
			EndIf
		Next nJ
		MsUnLock()

	Else

		If  !( StrTran( Upper( AllTrim( SX2->X2_UNICO ) ), " ", "" ) == StrTran( Upper( AllTrim( aSX2[nI][12]  ) ), " ", "" ) )
			RecLock( "SX2", .F. )
			SX2->X2_UNICO := aSX2[nI][12]
			MsUnlock()

			If MSFILE( RetSqlName( aSX2[nI][1] ),RetSqlName( aSX2[nI][1] ) + "_UNQ"  )
				TcInternal( 60, RetSqlName( aSX2[nI][1] ) + "|" + RetSqlName( aSX2[nI][1] ) + "_UNQ" )
			EndIf

			AutoGrLog( "Foi alterada a chave única da tabela " + aSX2[nI][1] )
		EndIf

		RecLock( "SX2", .F. )
		For nJ := 1 To Len( aSX2[nI] )
			If FieldPos( aEstrut[nJ] ) > 0
				If PadR( aEstrut[nJ], 10 ) $ cCpoUpd
					FieldPut( FieldPos( aEstrut[nJ] ), aSX2[nI][nJ] )
				EndIf

			EndIf
		Next nJ
		MsUnLock()

	EndIf

Next nI

AutoGrLog( CRLF + "Final da Atualização" + " SX2" + CRLF + Replicate( "-", 128 ) + CRLF )

Return NIL


//--------------------------------------------------------------------
/*/{Protheus.doc} FSAtuSX3

Função de processamento da gravação do SX3 - Campos

@author UPDATE gerado automaticamente
@since  02/05/2023
@obs    Gerado por EXPORDIC - V.7.5.2.2 EFS / Upd. V.5.3.1 EFS
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function FSAtuSX3()
Local aEstrut   := {}
Local aSX3      := {}
Local cAlias    := ""
Local cAliasAtu := ""
Local cSeqAtu   := ""
Local cX3Campo  := ""
Local cX3Dado   := ""
Local nI        := 0
Local nJ        := 0
Local nPosArq   := 0
Local nPosCpo   := 0
Local nPosOrd   := 0
Local nPosSXG   := 0
Local nPosTam   := 0
Local nPosVld   := 0
Local nSeqAtu   := 0
Local nTamSeek  := Len( SX3->X3_CAMPO )

AutoGrLog( "Ínicio da Atualização" + " SX3" + CRLF )

aEstrut := { { "X3_ARQUIVO", 0 }, { "X3_ORDEM"  , 0 }, { "X3_CAMPO"  , 0 }, { "X3_TIPO"   , 0 }, { "X3_TAMANHO", 0 }, { "X3_DECIMAL", 0 }, { "X3_TITULO" , 0 }, ;
             { "X3_TITSPA" , 0 }, { "X3_TITENG" , 0 }, { "X3_DESCRIC", 0 }, { "X3_DESCSPA", 0 }, { "X3_DESCENG", 0 }, { "X3_PICTURE", 0 }, { "X3_VALID"  , 0 }, ;
             { "X3_USADO"  , 0 }, { "X3_RELACAO", 0 }, { "X3_F3"     , 0 }, { "X3_NIVEL"  , 0 }, { "X3_RESERV" , 0 }, { "X3_CHECK"  , 0 }, { "X3_TRIGGER", 0 }, ;
             { "X3_PROPRI" , 0 }, { "X3_BROWSE" , 0 }, { "X3_VISUAL" , 0 }, { "X3_CONTEXT", 0 }, { "X3_OBRIGAT", 0 }, { "X3_VLDUSER", 0 }, { "X3_CBOX"   , 0 }, ;
             { "X3_CBOXSPA", 0 }, { "X3_CBOXENG", 0 }, { "X3_PICTVAR", 0 }, { "X3_WHEN"   , 0 }, { "X3_INIBRW" , 0 }, { "X3_GRPSXG" , 0 }, { "X3_FOLDER" , 0 }, ;
             { "X3_CONDSQL", 0 }, { "X3_CHKSQL" , 0 }, { "X3_IDXSRV" , 0 }, { "X3_ORTOGRA", 0 }, { "X3_TELA"   , 0 }, { "X3_POSLGT" , 0 }, { "X3_IDXFLD" , 0 }, ;
             { "X3_AGRUP"  , 0 }, { "X3_MODAL"  , 0 }, { "X3_PYME"   , 0 } }

aEval( aEstrut, { |x| x[2] := SX3->( FieldPos( x[1] ) ) } )


aAdd( aSX3, {{'RA1',.T.},{'01',.T.},{'RA1_FILIAL',.T.},{'C',.T.},{2,.T.},{0,.T.},{'Filial',.T.},{'Sucursal',.T.},{'Branch',.T.},{'Filial',.T.},{'Sucursal',.T.},{'System Branch',.T.},{'',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(129) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(132) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'033',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA1',.T.},{'02',.T.},{'RA1_CURSO',.T.},{'C',.T.},{4,.T.},{0,.T.},{'Cod.Curso',.T.},{'Curso',.T.},{'Course Code',.T.},{'Codigo do Curso',.T.},{'Codigo del Curso',.T.},{'Course Code',.T.},{'9999',.T.},{'NaoVazio() .And. ExistChav("RA1",M->RA1_CURSO) .And. VAL(M->RA1_CURSO) > 0 .And. FreeForUse("RA1",M->RA1_CURSO)',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(176),.T.},{'GetSX8Num("RA1","RA1_CURSO")',.T.},{'',.T.},{1,.T.},{Chr(135) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'S',.T.},{'V',.T.},{'R',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{"#RA1_CURSO <>'    '",.T.},{'S',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA1',.T.},{'03',.T.},{'RA1_PROD',.T.},{'C',.T.},{15,.T.},{0,.T.},{'Produto',.T.},{'Producto',.T.},{'Product',.T.},{'Codigo do Produto',.T.},{'Codigo del Producto',.T.},{'Product Code',.T.},{'@!',.T.},{'Vazio() .Or. ExistCpo("SB1")',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'SB1',.T.},{1,.T.},{Chr(134) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'030',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA1',.T.},{'04',.T.},{'RA1_DESC',.T.},{'C',.T.},{90,.T.},{0,.T.},{'Descricao',.T.},{'Descripcion',.T.},{'Description',.T.},{'Descricao do Curso',.T.},{'Descripcion del Curso',.T.},{'Course Description',.T.},{'@!',.T.},{'NaoVazio()',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(151) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'S',.T.},{'A',.T.},{'R',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{"#RA1_DESC  <>'                              '",.T.},{'S',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA1',.T.},{'05',.T.},{'RA1_TIPO',.T.},{'C',.T.},{1,.T.},{0,.T.},{'Tipo Curso',.T.},{'Tipo Curso',.T.},{'Course Tp',.T.},{'Tipo do Curso',.T.},{'Tipo del Curso',.T.},{'Course Type',.T.},{'@!',.T.},{'ExistCpo("SX5","R6"+M->RA1_TIPO) .AND. RA1TIPOVLD()',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'R6',.T.},{1,.T.},{Chr(150) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'S',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA1',.T.},{'06',.T.},{'RA1_AREA',.T.},{'C',.T.},{3,.T.},{0,.T.},{'Area',.T.},{'Area',.T.},{'Area',.T.},{'Area',.T.},{'Area',.T.},{'Area',.T.},{'999',.T.},{'ExistCpo("SX5","R1"+M->RA1_AREA)',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'R1',.T.},{1,.T.},{Chr(150) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'S',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA1',.T.},{'07',.T.},{'RA1_DURACA',.T.},{'N',.T.},{7,.T.},{2,.T.},{'Duracao',.T.},{'Duracion',.T.},{'Duration',.T.},{'Duracao',.T.},{'Duracion',.T.},{'Duration',.T.},{'9999.99',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(134) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA1',.T.},{'08',.T.},{'RA1_UNDURA',.T.},{'C',.T.},{1,.T.},{0,.T.},{'Unid.Duracao',.T.},{'Un.Duracion',.T.},{'Duration Un.',.T.},{'Tempo de Duracao',.T.},{'Tiempo de Duracion',.T.},{'Length of Time',.T.},{'@!',.T.},{'ExistCpo("SX5","R5"+M->RA1_UNDURA)',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'R5',.T.},{1,.T.},{Chr(150) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA1',.T.},{'09',.T.},{'RA1_VALOR',.T.},{'N',.T.},{12,.T.},{2,.T.},{'Valor',.T.},{'Valor',.T.},{'Value',.T.},{'Valor',.T.},{'Valor',.T.},{'Value',.T.},{'@E 999,999,999.99',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(150) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA1',.T.},{'10',.T.},{'RA1_HORAS',.T.},{'N',.T.},{7,.T.},{2,.T.},{'Horas',.T.},{'Horas',.T.},{'Hours',.T.},{'Horas',.T.},{'Horas',.T.},{'Hours',.T.},{'@R 9999.99',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(159) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA1',.T.},{'11',.T.},{'RA1_TIPOPP',.T.},{'C',.T.},{3,.T.},{0,.T.},{'Tp Curso Ext',.T.},{'Tp Curso Ext',.T.},{'Ext.Cour.Tp.',.T.},{'Tipo de Curso Externo',.T.},{'Tipo de Curso Externo',.T.},{'External Course Type',.T.},{'',.T.},{'Vazio() .Or. ExistCpo("SQX")',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'SQX',.T.},{1,.T.},{Chr(132) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'S',.T.},{'A',.T.},{'R',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA1',.T.},{'12',.T.},{'RA1_GRUPO',.T.},{'C',.T.},{2,.T.},{0,.T.},{'Grupo Curso',.T.},{'Grupo Curso',.T.},{'Cour.Grp.',.T.},{'Item do Grupo de Curso',.T.},{'Item del Grupo de Curso',.T.},{'Course Group Item',.T.},{'@!',.T.},{'(Vazio() .Or. ExistCpo("SQ0")) .and. Ra1GrupoVld()',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'SQ0',.T.},{1,.T.},{Chr(132) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'S',.T.},{'A',.T.},{'R',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA1',.T.},{'13',.T.},{'RA1_DESGRU',.T.},{'C',.T.},{30,.T.},{0,.T.},{'Desc.Grupo',.T.},{'Desc.Grupo',.T.},{'Grp. Descr.',.T.},{'Desc.Item do Grupo',.T.},{'Desc. Item del Grupo',.T.},{'Group Item Description',.T.},{'@!',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'Ra1DesGruInit()',.T.},{'',.T.},{1,.T.},{Chr(132) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'V',.T.},{'V',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA1',.T.},{'14',.T.},{'RA1_QTDMIN',.T.},{'C',.T.},{3,.T.},{0,.T.},{'Qtde Minima',.T.},{'Qtd Minima',.T.},{'Minim Qty',.T.},{'Qtde min p formar turma',.T.},{'Qtd min para hacer grupo',.T.},{'Minim Qty to make team',.T.},{'999',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{"'0'",.T.},{'',.T.},{1,.T.},{Chr(132) + Chr(128),.T.},{'',.T.},{'',.T.},{'S',.T.},{'S',.T.},{'A',.T.},{'R',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA1',.T.},{'15',.T.},{'RA1_IMPRIM',.T.},{'C',.T.},{1,.T.},{0,.T.},{'Imp.Fich.Reg',.T.},{'Imp.Fich.Reg',.T.},{'Print.Frm.Rg',.T.},{'Imprime na Ficha Registro',.T.},{'Imprime en la ficha Regis',.T.},{'Print Registration Form',.T.},{'@!',.T.},{"Pertence('12')",.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{"'2'",.T.},{'',.T.},{1,.T.},{Chr(134) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'A',.T.},{'R',.T.},{'',.T.},{'',.T.},{'1=Sim;2=Não',.T.},{'1=Si;2=No',.T.},{'1=Yes;2=No',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'1',.T.},{'',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA1',.T.},{'16',.T.},{'RA1_CATEG',.T.},{'C',.T.},{3,.T.},{0,.T.},{'Categoria',.T.},{'Categoría',.T.},{'Category',.T.},{'Código da Categoria',.T.},{'Código de la categoría',.T.},{'Category Code',.T.},{'@!',.T.},{'Vazio() .or. ExistCpo("AIQ")',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'AIQ',.T.},{1,.T.},{Chr(134) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'A',.T.},{'R',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA1',.T.},{'17',.T.},{'RA1_CJETAP',.T.},{'C',.T.},{6,.T.},{0,.T.},{'Conj. Etapa',.T.},{'Conj. Etapa',.T.},{'Set Stage',.T.},{'Código do Conj. de Etapas',.T.},{'Código Conj. Etapas',.T.},{'Stage Set Code',.T.},{'999999',.T.},{'VldCjEtp()',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'AP0',.T.},{1,.T.},{Chr(132) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'A',.T.},{'R',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )

aAdd( aSX3, {{'RA4',.T.},{'01',.T.},{'RA4_FILIAL',.T.},{'C',.T.},{2,.T.},{0,.T.},{'Filial',.T.},{'Sucursal',.T.},{'Branch',.T.},{'Filial',.T.},{'Sucursal',.T.},{'System Branch',.T.},{'',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(129) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128),.T.},{'',.T.},{'XM0',.T.},{1,.T.},{Chr(132) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'A',.T.},{'R',.T.},{'',.T.},{'SX3INSERTTRAINING():RA4FilialX3VldUser()',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'033',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'02',.T.},{'RA4_MAT',.T.},{'C',.T.},{6,.T.},{0,.T.},{'Matricula',.T.},{'Matricula',.T.},{'Registration',.T.},{'Matricula',.T.},{'Matricula',.T.},{'Registration',.T.},{'999999',.T.},{'NaoVazio()',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'SRA',.T.},{1,.T.},{Chr(151) + Chr(128),.T.},{'',.T.},{'S',.T.},{'',.T.},{'S',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'121',.T.},{'',.T.},{'',.T.},{"#RA4_MAT   <>'      '",.T.},{'S',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'03',.T.},{'RA4_NOME',.T.},{'C',.T.},{30,.T.},{0,.T.},{'Nome',.T.},{'Nombre',.T.},{'Name',.T.},{'Nome',.T.},{'Nombre',.T.},{'Name',.T.},{'@!',.T.},{'',.T.},{ Chr(129) + Chr(128) + Chr(171) + Chr(220) + Chr(128) +Chr(228) + Chr(132) + Chr(128) + Chr(128) + Chr(145) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128),.T.},{'IF(INCLUI,Space(GetSx3Cache("RA4_NOME","X3_TAMANHO")),FDesc("SRA",RA4->RA4_MAT,"SRA->RA_NOME",30))',.T.},{'',.T.},{1,.T.},{Chr(150) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'V',.T.},{'V',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'04',.T.},{'RA4_CURSO',.T.},{'C',.T.},{4,.T.},{0,.T.},{'Cod.Curso',.T.},{'Cod.Curso',.T.},{'Course Cd',.T.},{'Codigo do Sinonimo',.T.},{'Codigo del Sinonimo',.T.},{'Synonim Code',.T.},{'9999',.T.},{'ExistCpo("RA1") .and. NaoVazio() .And. Tr100RetDesc() .And. Tr100Exist(1)',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'AIQRA1',.T.},{1,.T.},{Chr(151) + Chr(128),.T.},{'',.T.},{'S',.T.},{'',.T.},{'S',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{"#RA4_CURSO <>'    '",.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'05',.T.},{'RA4_DESCCU',.T.},{'C',.T.},{30,.T.},{0,.T.},{'Desc.Curso',.T.},{'Desc.Curso',.T.},{'Course Desc.',.T.},{'Descricao do Curso',.T.},{'Descrip. del Curso',.T.},{'Course Description',.T.},{'@!',.T.},{'',.T.},{ Chr(129) + Chr(128) + Chr(171) + Chr(220) + Chr(128) +Chr(228) + Chr(132) + Chr(128) + Chr(128) + Chr(145) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128),.T.},{'IF(INCLUI,Space(GetSx3Cache("RA4_DESCCU","X3_TAMANHO")),FDesc("RA1",RA4->RA4_CURSO,"RA1->RA1_DESC",30))',.T.},{'',.T.},{1,.T.},{Chr(150) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'V',.T.},{'V',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'06',.T.},{'RA4_SINONI',.T.},{'C',.T.},{4,.T.},{0,.T.},{'Cod.Sinonimo',.T.},{'Cod.Sinonimo',.T.},{'Syn. Cd',.T.},{'Codigo do Sinonimo',.T.},{'Codigo del Sinonimo',.T.},{'Syn. Code',.T.},{'9999',.T.},{'NaoVazio() .And. Tr100RetDesc() .And. Tr100Exist(3)',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'RA9',.T.},{1,.T.},{Chr(132) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'S',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'07',.T.},{'RA4_DESCSI',.T.},{'C',.T.},{30,.T.},{0,.T.},{'Desc.Sinonim',.T.},{'Desc.Sinonim',.T.},{'Syn. Desc',.T.},{'Descricao do Sinonimo',.T.},{'Descrip. del Sinonimo',.T.},{'Synonym Desc',.T.},{'@!',.T.},{'',.T.},{ Chr(129) + Chr(128) + Chr(171) + Chr(220) + Chr(128) +Chr(228) + Chr(132) + Chr(128) + Chr(128) + Chr(145) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128),.T.},{'IF(INCLUI,Space(GetSx3Cache("RA4_DESCSI","X3_TAMANHO")),FDesc("RA9",RA4->RA4_SINONI,"RA9->RA9_DESCR",30))',.T.},{'',.T.},{1,.T.},{Chr(150) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'V',.T.},{'V',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'08',.T.},{'RA4_ENTIDA',.T.},{'C',.T.},{4,.T.},{0,.T.},{'Cod.Entidade',.T.},{'Cod.Ente',.T.},{'Ent. desc',.T.},{'Codigo da Entidade',.T.},{'Codigo del Ente',.T.},{'Entity Description',.T.},{'9999',.T.},{'NaoVazio() .And. Tr100RetDesc() .And. Tr100Exist(2)'                                        ,.T.},{ Chr(129) + Chr(128) + Chr(171) + Chr(220) + Chr(128) +Chr(132) + Chr(132) + Chr(128) + Chr(128) + Chr(145) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128),.T.},{'',.T.},{'RA6',.T.},{1,.T.},{Chr(150) + Chr(192),.T.},{'',.T.},{'S',.T.},{'',.T.},{'S',.T.},{'',.T.},{'',.T.},{'',.T.},{'SX3INSERTTRAINING():RA4EntidaX3VldUser()',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'Ra4EntidWhen()',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'09',.T.},{'RA4_DESCEN',.T.},{'C',.T.},{30,.T.},{0,.T.},{'Desc.Entid.',.T.},{'Desc.Ente',.T.},{'Ent. Desc.',.T.},{'Descricao da Entidade',.T.},{'Descrip. del Ente',.T.},{'Entity Desc.',.T.},{'@!',.T.},{'',.T.},{ Chr(129) + Chr(128) + Chr(139) + Chr(220) + Chr(128) +Chr(228) + Chr(132) + Chr(128) + Chr(128) + Chr(145) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128),.T.},{'IF(INCLUI,Space(GetSx3Cache("RA4_DESCEN","X3_TAMANHO")),FDesc("RA0",RA4->RA4_ENTIDA,"RA0->RA0_DESC",30))',.T.},{'',.T.},{1,.T.},{Chr(150) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'V',.T.},{'V',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'10',.T.},{'RA4_VALIDA',.T.},{'D',.T.},{8,.T.},{0,.T.},{'Dt.Validade',.T.},{'Fch Validez',.T.},{'Valid. Dt',.T.},{'Data Validade',.T.},{'Fecha Validez',.T.},{'Validity Date',.T.},{'',.T.},{'',.T.},{ Chr(129) + Chr(128) + Chr(171) + Chr(220) + Chr(128) +Chr(228) + Chr(132) + Chr(128) + Chr(128) + Chr(145) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128),.T.},{'CTOD("  /  /  ")',.T.},{'',.T.},{1,.T.},{Chr(150) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'11',.T.},{'RA4_NOTA',.T.},{'N',.T.},{12,.T.},{2,.T.},{'Nota',.T.},{'Nota',.T.},{'Grade',.T.},{'Nota',.T.},{'Nota',.T.},{'Grade',.T.},{'999,999,999.99',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(150) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'12',.T.},{'RA4_DURACA',.T.},{'N',.T.},{7,.T.},{2,.T.},{'Duracao',.T.},{'Duracion',.T.},{'Duration',.T.},{'Duracao',.T.},{'Duracion',.T.},{'Duration',.T.},{'@E 9999.99',.T.},{'Positivo()',.T.},{ Chr(129) + Chr(128) + Chr(171) + Chr(220) + Chr(128) +Chr(132) + Chr(132) + Chr(128) + Chr(128) + Chr(145) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(134) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'13',.T.},{'RA4_UNDURA',.T.},{'C',.T.},{1,.T.},{0,.T.},{'Un.Duracao',.T.},{'Un.Duracion',.T.},{'Last. Unit',.T.},{'Unidade de Duracao',.T.},{'Unidad de Duracion',.T.},{'Lasting Unit',.T.},{'@!',.T.},{'Existcpo("SX5","R5"+M->RA4_UNDURA)',.T.},{ Chr(129) + Chr(128) + Chr(171) + Chr(220) + Chr(128) +Chr(132) + Chr(132) + Chr(128) + Chr(128) + Chr(145) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128),.T.},{'',.T.},{'R5',.T.},{1,.T.},{Chr(150) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'14',.T.},{'RA4_PRESEN',.T.},{'N',.T.},{6,.T.},{2,.T.},{'% Presenca',.T.},{'% Presencia',.T.},{'% Presence',.T.},{'% Presenca',.T.},{'% Presencia',.T.},{'% Presence',.T.},{'999.99',.T.},{'M->RA4_PRESEN <= 100',.T.},{ Chr(129) + Chr(128) + Chr(171) + Chr(220) + Chr(128) +Chr(132) + Chr(132) + Chr(128) + Chr(128) + Chr(145) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(150) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'15',.T.},{'RA4_DATAIN',.T.},{'D',.T.},{8,.T.},{0,.T.},{'Data Inicio',.T.},{'Fch Inicial',.T.},{'Initial Date',.T.},{'Data Inicio',.T.},{'Fecha Inicial',.T.},{'Initial Date',.T.},{'',.T.},{'',.T.},{ Chr(129) + Chr(128) + Chr(171) + Chr(220) + Chr(128) +Chr(228) + Chr(132) + Chr(128) + Chr(128) + Chr(145) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128),.T.},{'CTOD("  /  /  ")',.T.},{'',.T.},{1,.T.},{Chr(151) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'16',.T.},{'RA4_DATAFI',.T.},{'D',.T.},{8,.T.},{0,.T.},{'Data Fim',.T.},{'Fch Final',.T.},{'Final Dt',.T.},{'Data Fim',.T.},{'Fecha Final',.T.},{'Final Date',.T.},{'',.T.},{'',.T.},{ Chr(129) + Chr(128) + Chr(171) + Chr(220) + Chr(128) +Chr(132) + Chr(132) + Chr(128) + Chr(128) + Chr(145) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128),.T.},{'CTOD("  /  /  ")',.T.},{'',.T.},{1,.T.},{Chr(150) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'17',.T.},{'RA4_VALOR',.T.},{'N',.T.},{12,.T.},{2,.T.},{'Valor',.T.},{'Valor',.T.},{'Value',.T.},{'Valor',.T.},{'Valor',.T.},{'Value',.T.},{'@R 999,999,999.99',.T.},{'',.T.},{ Chr(129) + Chr(128) + Chr(171) + Chr(220) + Chr(128) +Chr(228) + Chr(132) + Chr(128) + Chr(128) + Chr(145) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(150) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'18',.T.},{'RA4_HORAS',.T.},{'N',.T.},{7,.T.},{2,.T.},{'Horas',.T.},{'Horas',.T.},{'Hours',.T.},{'Horas',.T.},{'Horas',.T.},{'Hours',.T.},{'9999.99',.T.},{'Positivo()',.T.},{ Chr(129) + Chr(128) + Chr(171) + Chr(220) + Chr(128) +Chr(228) + Chr(132) + Chr(128) + Chr(128) + Chr(145) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(150) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'19',.T.},{'RA4_CALEND',.T.},{'C',.T.},{4,.T.},{0,.T.},{'Calendario',.T.},{'Calendario',.T.},{'Schedule',.T.},{'Calendario',.T.},{'Calendario',.T.},{'Schedule',.T.},{'9999',.T.},{'',.T.},{ Chr(129) + Chr(128) + Chr(171) + Chr(220) + Chr(128) +Chr(132) + Chr(132) + Chr(128) + Chr(128) + Chr(145) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(150) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'20',.T.},{'RA4_TURMA',.T.},{'C',.T.},{3,.T.},{0,.T.},{'Turma',.T.},{'Grupo',.T.},{'Division',.T.},{'Turma',.T.},{'Grupo',.T.},{'Division',.T.},{'999',.T.},{'',.T.},{ Chr(129) + Chr(128) + Chr(171) + Chr(220) + Chr(128) +Chr(228) + Chr(132) + Chr(128) + Chr(128) + Chr(145) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(150) + Chr(192),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'21',.T.},{'RA4_EFICAC',.T.},{'N',.T.},{6,.T.},{2,.T.},{'Eficacia',.T.},{'Eficacia',.T.},{'Effectiven.',.T.},{'Avaliacao Eficacia',.T.},{'Evaluacion Eficacia',.T.},{'Effectiveness Evaluation',.T.},{'@E 999.99',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(134) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'22',.T.},{'RA4_EFICSN',.T.},{'C',.T.},{1,.T.},{0,.T.},{'Eficaz',.T.},{'Eficaz',.T.},{'Effective',.T.},{'Eficaz',.T.},{'Eficaz',.T.},{'Effective',.T.},{'9',.T.},{'Pertence("12")',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'"2"',.T.},{'',.T.},{1,.T.},{Chr(134) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'1=SIM; 2=NAO',.T.},{'1=SI; 2=NO',.T.},{'1=Yes;2=No',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'23',.T.},{'RA4_TIPO',.T.},{'C',.T.},{1,.T.},{0,.T.},{'Origem',.T.},{'Origen',.T.},{'Origin',.T.},{'Origem do Treinamento',.T.},{'Origen de la Capacitacion',.T.},{'Training Origin',.T.},{'@!',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(134) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'V',.T.},{'R',.T.},{'',.T.},{'',.T.},{' = Normal; 1 = Coletivo',.T.},{' = Normal; 1 = Colectivo',.T.},{'= Regular; 1 = Colective',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'24',.T.},{'RA4_NIVEL',.T.},{'C',.T.},{2,.T.},{0,.T.},{'Nivel',.T.},{'Nivel',.T.},{'Level',.T.},{'Nivel',.T.},{'Nivel',.T.},{'Level',.T.},{'',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(132) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'S',.T.},{'A',.T.},{'R',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'25',.T.},{'RA4_STATUS',.T.},{'C',.T.},{2,.T.},{0,.T.},{'Status',.T.},{'Estatus',.T.},{'Status',.T.},{'Status',.T.},{'Estatus',.T.},{'Status',.T.},{'',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(132) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'S',.T.},{'A',.T.},{'R',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'26',.T.},{'RA4_DTALT',.T.},{'D',.T.},{8,.T.},{0,.T.},{'Dt ult alter',.T.},{'Fch. ult alt',.T.},{'Lst.Mod.Date',.T.},{'Data da ultima alteracao',.T.},{'Fecha ultima alteracion',.T.},{'Last Modification Date',.T.},{'',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(132) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'S',.T.},{'A',.T.},{'R',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'27',.T.},{'RA4_CODCOM',.T.},{'C',.T.},{6,.T.},{0,.T.},{'Cod comentar',.T.},{'Cod comentar',.T.},{'Comment Code',.T.},{'Codigo do comentario',.T.},{'Codigo de comentario',.T.},{'Comment Code',.T.},{'',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(132) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'S',.T.},{'A',.T.},{'R',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'28',.T.},{'RA4_CONTEU',.T.},{'M',.T.},{10,.T.},{0,.T.},{'Conteudo',.T.},{'Contenido',.T.},{'Content',.T.},{'Conteudo',.T.},{'Contenido',.T.},{'Content',.T.},{'',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(132) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'S',.T.},{'A',.T.},{'R',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'29',.T.},{'RA4_CATCUR',.T.},{'C',.T.},{3,.T.},{0,.T.},{'Categoria',.T.},{'Categoría',.T.},{'Category',.T.},{'Código da Categoria',.T.},{'Código de la categoría',.T.},{'Category Code',.T.},{'@!',.T.},{'Vazio() .or. ExistCpo("AIQ")',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'IIF( INCLUI, "", POSICIONE("RA1", 1, XFILIAL("RA1") + RA4->RA4_CURSO, "RA1_CATEG") )',.T.},{'AIQ',.T.},{1,.T.},{Chr(134) + Chr(128),.T.},{'',.T.},{'S',.T.},{'',.T.},{'N',.T.},{'A',.T.},{'R',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'30',.T.},{'RA4_CATDES',.T.},{'C',.T.},{40,.T.},{0,.T.},{'Descrição',.T.},{'Descripción',.T.},{'Description',.T.},{'Descrição da Categoria',.T.},{'Descripción de categoría',.T.},{'Category Description',.T.},{'',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'INIRA4CAT()',.T.},{'',.T.},{1,.T.},{Chr(134) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'S',.T.},{'V',.T.},{'V',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'31',.T.},{'RA4_UMODAL',.T.},{'C',.T.},{1,.T.},{0,.T.},{'Modalidade',.T.},{'Modalidade',.T.},{'Modalidade',.T.},{'Modalidade do Treinamento',.T.},{'Modalidade do Treinamento',.T.},{'Modalidade do Treinamento',.T.},{'@!',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'',.T.},{0,.T.},{Chr(254) + Chr(192),.T.},{'',.T.},{'',.T.},{'U',.T.},{'S',.T.},{'A',.T.},{'R',.T.},{'',.T.},{'Pertence("12")',.T.},{'1=Presencial;2=Online',.T.},{'1=Presencial;2=Online',.T.},{'1=Presencial;2=Online',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'32',.T.},{'RA4_UAVREC',.T.},{'C',.T.},{1,.T.},{0,.T.},{'Av.de Reação',.T.},{'Av.de Reação',.T.},{'Av.de Reação',.T.},{'Avaliação de Reação',.T.},{'Avaliação de Reação',.T.},{'Avaliação de Reação',.T.},{'@!',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'',.T.},{0,.T.},{Chr(254) + Chr(192),.T.},{'',.T.},{'',.T.},{'U',.T.},{'S',.T.},{'A',.T.},{'R',.T.},{'',.T.},{'Pertence("01")',.T.},{'0=Não;1=Sim',.T.},{'0=Não;1=Sim',.T.},{'0=Não;1=Sim',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'33',.T.},{'RA4_ULIDER',.T.},{'C',.T.},{6,.T.},{0,.T.},{'Liderança',.T.},{'Liderança',.T.},{'Liderança',.T.},{'Liderança',.T.},{'Liderança',.T.},{'Liderança',.T.},{'@!',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'U__RD0',.T.},{0,.T.},{Chr(254) + Chr(192),.T.},{'',.T.},{'S',.T.},{'U',.T.},{'S',.T.},{'A',.T.},{'R',.T.},{'',.T.},{'ExistCPO("RD0")',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.}} )
aAdd( aSX3, {{'RA4',.T.},{'34',.T.},{'RA4_UNOMEL',.T.},{'C',.T.},{60,.T.},{0,.T.},{'Nome Lider',.T.},{'Nome Lider',.T.},{'Nome Lider',.T.},{'Nome Lider',.T.},{'Nome Lider',.T.},{'Nome Lider',.T.},{'@!',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'',.T.},{0,.T.},{Chr(254) + Chr(192),.T.},{'',.T.},{'',.T.},{'U',.T.},{'N',.T.},{'V',.T.},{'V',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.}} )

aAdd( aSX3, {{'RA6',.T.},{'01',.T.},{'RA6_FILIAL',.T.},{'C',.T.},{2,.T.},{0,.T.},{'Filial',.T.},{'Sucursal',.T.},{'Branch',.T.},{'Filial',.T.},{'Sucursal',.T.},{'System Branch',.T.},{'',.T.},{'',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(129) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(132) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'033',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA6',.T.},{'02',.T.},{'RA6_ENTIDA',.T.},{'C',.T.},{4,.T.},{0,.T.},{'Cod.Entidade',.T.},{'Entidad',.T.},{'Entity Code',.T.},{'Codigo da Entidade',.T.},{'Codigo de la Entidad',.T.},{'Entity Code',.T.},{'9999',.T.},{'NaoVazio() .And. ExistCpo("RA0") .And. IF(FWISINCALLSTACK("U_INSTRM"),.t.,Tr010Desc(.F.))',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'RA0',.T.},{1,.T.},{Chr(135) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'S',.T.},{'',.T.},{'',.T.},{'',.T.},{'SX3INSERTTRAINING():RA6EntidaX3VldUser()',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{"#RA6_ENTIDA<>'    '",.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA6',.T.},{'03',.T.},{'RA6_CURSO',.T.},{'C',.T.},{4,.T.},{0,.T.},{'Cod.Curso',.T.},{'Curso',.T.},{'Course Code',.T.},{'Codigo do Curso',.T.},{'Codigo del Curso',.T.},{'Course Code',.T.},{'9999',.T.},{'NaoVazio() .And. ExistCpo("RA1") .And. IF(FWISINCALLSTACK("U_INSTRM"),.t.,Tr010Desc(.F.))',.T.},{ Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(128) +Chr(128) + Chr(128) + Chr(128) + Chr(128) + Chr(160),.T.},{'',.T.},{'RA1',.T.},{1,.T.},{Chr(135) + Chr(128),.T.},{'',.T.},{'S',.T.},{'',.T.},{'S',.T.},{'',.T.},{'',.T.},{'',.T.},{'SX3INSERTTRAINING():RA6CursoX3VldUser()',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{"#RA6_CURSO <>'    '",.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA6',.T.},{'04',.T.},{'RA6_DESC',.T.},{'C',.T.},{30,.T.},{0,.T.},{'Descricao',.T.},{'Descripcion',.T.},{'Description',.T.},{'Descricao Entidade/Curso',.T.},{'Descripcion Entidad/Curso',.T.},{'Entity/Course Description',.T.},{'@!',.T.},{'',.T.},{ Chr(129) + Chr(128) + Chr(138) + Chr(132) + Chr(129) +Chr(132) + Chr(128) + Chr(128) + Chr(132) + Chr(128) +Chr(128) + Chr(128) + Chr(160) + Chr(128) + Chr(128),.T.},{'IF(FWISINCALLSTACK("U_INSTRM"),SPACE(GETSX3CACHE("RA6_DESC","X3_TAMANHO")),Tr010Desc(.T.))',.T.},{'',.T.},{1,.T.},{Chr(134) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'V',.T.},{'V',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA6',.T.},{'05',.T.},{'RA6_DURACA',.T.},{'N',.T.},{7,.T.},{2,.T.},{'Duracao',.T.},{'Duracion',.T.},{'Duration',.T.},{'Duracao',.T.},{'Duracion',.T.},{'Duration',.T.},{'@E 9999.99',.T.},{'Positivo()',.T.},{ Chr(129) + Chr(128) + Chr(138) + Chr(132) + Chr(129) +Chr(132) + Chr(128) + Chr(128) + Chr(132) + Chr(128) +Chr(128) + Chr(128) + Chr(160) + Chr(128) + Chr(128),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(134) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'S',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA6',.T.},{'06',.T.},{'RA6_UNID',.T.},{'C',.T.},{1,.T.},{0,.T.},{'Unidade',.T.},{'Unidad',.T.},{'Unity',.T.},{'Unidade de Duracao',.T.},{'Unidad de Duracion',.T.},{'Duration Unity',.T.},{'@!',.T.},{'ExistCpo("SX5","R5"+M->RA6_UNID)',.T.},{ Chr(129) + Chr(128) + Chr(138) + Chr(132) + Chr(129) +Chr(132) + Chr(128) + Chr(128) + Chr(132) + Chr(128) +Chr(128) + Chr(128) + Chr(160) + Chr(128) + Chr(128),.T.},{'',.T.},{'R5',.T.},{1,.T.},{Chr(134) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'S',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA6',.T.},{'07',.T.},{'RA6_VALOR',.T.},{'N',.T.},{12,.T.},{2,.T.},{'Valor',.T.},{'Valor',.T.},{'Value',.T.},{'Valor do Curso',.T.},{'Valor del Curso',.T.},{'Course Value',.T.},{'999999999.99',.T.},{'Positivo()',.T.},{ Chr(129) + Chr(128) + Chr(138) + Chr(132) + Chr(129) +Chr(132) + Chr(128) + Chr(128) + Chr(132) + Chr(128) +Chr(128) + Chr(128) + Chr(160) + Chr(128) + Chr(128),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(158) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'S',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA6',.T.},{'08',.T.},{'RA6_CONTEU',.T.},{'M',.T.},{10,.T.},{0,.T.},{'Conteudo',.T.},{'Contenido',.T.},{'Contents',.T.},{'Conteudo do Curso',.T.},{'Contenido del Curso',.T.},{'Course Contents',.T.},{'',.T.},{'',.T.},{ Chr(129) + Chr(128) + Chr(138) + Chr(132) + Chr(129) +Chr(132) + Chr(128) + Chr(128) + Chr(132) + Chr(128) +Chr(128) + Chr(128) + Chr(160) + Chr(128) + Chr(128),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(134) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )
aAdd( aSX3, {{'RA6',.T.},{'09',.T.},{'RA6_DTCOTA',.T.},{'D',.T.},{8,.T.},{0,.T.},{'Data Cotacao',.T.},{'Fecha Cotiz.',.T.},{'Quota. Date',.T.},{'Data da Cotacao',.T.},{'Fecha de la Cotizacion',.T.},{'Quoatation Date',.T.},{'',.T.},{'',.T.},{ Chr(129) + Chr(128) + Chr(138) + Chr(132) + Chr(129) +Chr(132) + Chr(128) + Chr(128) + Chr(132) + Chr(128) +Chr(128) + Chr(128) + Chr(160) + Chr(128) + Chr(128),.T.},{'',.T.},{'',.T.},{1,.T.},{Chr(134) + Chr(128),.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'',.T.},{'N',.T.},{'N',.T.},{'',.T.},{'1',.T.},{'N',.T.},{'',.T.},{'2',.T.},{'S',.T.}} )

//
// Atualizando dicionário
//
nPosArq := aScan( aEstrut, { |x| AllTrim( x[1] ) == "X3_ARQUIVO" } )
nPosOrd := aScan( aEstrut, { |x| AllTrim( x[1] ) == "X3_ORDEM"   } )
nPosCpo := aScan( aEstrut, { |x| AllTrim( x[1] ) == "X3_CAMPO"   } )
nPosTam := aScan( aEstrut, { |x| AllTrim( x[1] ) == "X3_TAMANHO" } )
nPosSXG := aScan( aEstrut, { |x| AllTrim( x[1] ) == "X3_GRPSXG"  } )
nPosVld := aScan( aEstrut, { |x| AllTrim( x[1] ) == "X3_VALID"   } )

aSort( aSX3,,, { |x,y| x[nPosArq][1]+x[nPosOrd][1]+x[nPosCpo][1] < y[nPosArq][1]+y[nPosOrd][1]+y[nPosCpo][1] } )

oProcess:SetRegua2( Len( aSX3 ) )

dbSelectArea( "SX3" )
dbSetOrder( 2 )
cAliasAtu := ""

For nI := 1 To Len( aSX3 )

	//
	// Verifica se o campo faz parte de um grupo e ajusta tamanho
	//
	If !Empty( aSX3[nI][nPosSXG][1] )
		SXG->( dbSetOrder( 1 ) )
		If SXG->( MSSeek( aSX3[nI][nPosSXG][1] ) )
			If aSX3[nI][nPosTam][1] <> SXG->XG_SIZE
				aSX3[nI][nPosTam][1] := SXG->XG_SIZE
				AutoGrLog( "O tamanho do campo " + aSX3[nI][nPosCpo][1] + " NÃO atualizado e foi mantido em [" + ;
				AllTrim( Str( SXG->XG_SIZE ) ) + "]" + CRLF + ;
				" por pertencer ao grupo de campos [" + SXG->XG_GRUPO + "]" + CRLF )
			EndIf
		EndIf
	EndIf

	SX3->( dbSetOrder( 2 ) )

	If !( aSX3[nI][nPosArq][1] $ cAlias )
		cAlias += aSX3[nI][nPosArq][1] + "/"
		aAdd( aArqUpd, aSX3[nI][nPosArq][1] )
	EndIf

	If !SX3->( dbSeek( PadR( aSX3[nI][nPosCpo][1], nTamSeek ) ) )

		//
		// Busca ultima ocorrencia do alias
		//
		If ( aSX3[nI][nPosArq][1] <> cAliasAtu )
			cSeqAtu   := "00"
			cAliasAtu := aSX3[nI][nPosArq][1]

			dbSetOrder( 1 )
			SX3->( dbSeek( cAliasAtu + "ZZ", .T. ) )
			dbSkip( -1 )

			If ( SX3->X3_ARQUIVO == cAliasAtu )
				cSeqAtu := SX3->X3_ORDEM
			EndIf

			nSeqAtu := Val( RetAsc( cSeqAtu, 3, .F. ) )
		EndIf

		nSeqAtu++
		cSeqAtu := RetAsc( Str( nSeqAtu ), 2, .T. )

		RecLock( "SX3", .T. )
		For nJ := 1 To Len( aSX3[nI] )
			If     nJ == nPosOrd  // Ordem
				SX3->( FieldPut( FieldPos( aEstrut[nJ][1] ), cSeqAtu ) )

			ElseIf aEstrut[nJ][2] > 0
				SX3->( FieldPut( FieldPos( aEstrut[nJ][1] ), aSX3[nI][nJ][1] ) )

			EndIf
		Next nJ

		dbCommit()
		MsUnLock()

		AutoGrLog( "Criado campo " + aSX3[nI][nPosCpo][1] )

	Else

		//
		// Verifica se o campo faz parte de um grupo e ajsuta tamanho
		//
		If !Empty( SX3->X3_GRPSXG ) .AND. SX3->X3_GRPSXG <> aSX3[nI][nPosSXG][1]
			SXG->( dbSetOrder( 1 ) )
			If SXG->( MSSeek( SX3->X3_GRPSXG ) )
				If aSX3[nI][nPosTam][1] <> SXG->XG_SIZE
					aSX3[nI][nPosTam][1] := SXG->XG_SIZE
					AutoGrLog( "O tamanho do campo " + aSX3[nI][nPosCpo][1] + " NÃO atualizado e foi mantido em [" + ;
					AllTrim( Str( SXG->XG_SIZE ) ) + "]"+ CRLF + ;
					"   por pertencer ao grupo de campos [" + SX3->X3_GRPSXG + "]" + CRLF )
				EndIf
			EndIf
		EndIf

		//
		// Verifica todos os campos
		//
		For nJ := 1 To Len( aSX3[nI] )

			If aSX3[nI][nJ][2]
				cX3Campo := AllTrim( aEstrut[nJ][1] )
				cX3Dado  := SX3->( FieldGet( aEstrut[nJ][2] ) )

				If  aEstrut[nJ][2] > 0 .AND. ;
					PadR( StrTran( AllToChar( cX3Dado ), " ", "" ), 250 ) <> ;
					PadR( StrTran( AllToChar( aSX3[nI][nJ][1] ), " ", "" ), 250 ) .AND. ;
					!cX3Campo  == "X3_ORDEM"

					AutoGrLog( "Alterado campo " + aSX3[nI][nPosCpo][1] + CRLF + ;
					"   " + PadR( cX3Campo, 10 ) + " de [" + AllToChar( cX3Dado ) + "]" + CRLF + ;
					"            para [" + AllToChar( aSX3[nI][nJ][1] )           + "]" + CRLF )

					RecLock( "SX3", .F. )
					FieldPut( FieldPos( aEstrut[nJ][1] ), aSX3[nI][nJ][1] )
					MsUnLock()
				EndIf
			EndIf
		Next

	EndIf

	oProcess:IncRegua2( "Atualizando Campos de Tabelas (SX3) ..." )

Next nI

AutoGrLog( CRLF + "Final da Atualização" + " SX3" + CRLF + Replicate( "-", 128 ) + CRLF )

Return NIL


//--------------------------------------------------------------------
/*/{Protheus.doc} FSAtuSIX

Função de processamento da gravação do SIX - Indices

@author UPDATE gerado automaticamente
@since  02/05/2023
@obs    Gerado por EXPORDIC - V.7.5.2.2 EFS / Upd. V.5.3.1 EFS
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function FSAtuSIX()
Local aEstrut   := {}
Local aSIX      := {}
Local lAlt      := .F.
Local lDelInd   := .F.
Local nI        := 0
Local nJ        := 0

AutoGrLog( "Ínicio da Atualização" + " SIX" + CRLF )

aEstrut := { "INDICE" , "ORDEM" , "CHAVE", "DESCRICAO", "DESCSPA"  , ;
             "DESCENG", "PROPRI", "F3"   , "NICKNAME" , "SHOWPESQ" }

aAdd( aSIX, {'RA4','4','RA4_FILIAL+RA4_MAT+RA4_CALEND+RA4_CURSO+RA4_TURMA+RA4_SINONI+DTOS(RA4_DATAIN)','Calendario + Cod.Curso + Turma + Matricula','Calendario + Cod.Curso + Turma + Matricula','Calendario + Cod.Curso + Turma + Matricula','U','','','S'} )
//
// Atualizando dicionário
//
oProcess:SetRegua2( Len( aSIX ) )

dbSelectArea( "SIX" )
SIX->( dbSetOrder( 1 ) )

For nI := 1 To Len( aSIX )

	lAlt    := .F.
	lDelInd := .F.

	If !SIX->( dbSeek( aSIX[nI][1] + aSIX[nI][2] ) )
		AutoGrLog( "Índice criado " + aSIX[nI][1] + "/" + aSIX[nI][2] + " - " + aSIX[nI][3] )
	Else
		lAlt := .T.
		aAdd( aArqUpd, aSIX[nI][1] )
		If !StrTran( Upper( AllTrim( CHAVE )       ), " ", "" ) == ;
		    StrTran( Upper( AllTrim( aSIX[nI][3] ) ), " ", "" )
			AutoGrLog( "Chave do índice alterado " + aSIX[nI][1] + "/" + aSIX[nI][2] + " - " + aSIX[nI][3] )
			lDelInd := .T. // Se for alteração precisa apagar o indice do banco
		EndIf
	EndIf

	RecLock( "SIX", !lAlt )
	For nJ := 1 To Len( aSIX[nI] )
		If FieldPos( aEstrut[nJ] ) > 0
			FieldPut( FieldPos( aEstrut[nJ] ), aSIX[nI][nJ] )
		EndIf
	Next nJ
	MsUnLock()

	dbCommit()

	If lDelInd
		TcInternal( 60, RetSqlName( aSIX[nI][1] ) + "|" + RetSqlName( aSIX[nI][1] ) + aSIX[nI][2] )
	EndIf

	oProcess:IncRegua2( "Atualizando índices ..." )

Next nI

AutoGrLog( CRLF + "Final da Atualização" + " SIX" + CRLF + Replicate( "-", 128 ) + CRLF )

Return NIL


//--------------------------------------------------------------------
/*/{Protheus.doc} FSAtuSX6

Função de processamento da gravação do SX6 - Parâmetros

@author UPDATE gerado automaticamente
@since  02/05/2023
@obs    Gerado por EXPORDIC - V.7.5.2.2 EFS / Upd. V.5.3.1 EFS
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function FSAtuSX6()
Local aEstrut   := {}
Local aSX6      := {}
Local cAlias    := ""
Local lContinua := .T.
Local lReclock  := .T.
Local nI        := 0
Local nJ        := 0
Local nTamFil   := Len( SX6->X6_FIL )
Local nTamVar   := Len( SX6->X6_VAR )

AutoGrLog( "Ínicio da Atualização" + " SX6" + CRLF )

aEstrut := { "X6_FIL"    , "X6_VAR"    , "X6_TIPO"   , "X6_DESCRIC", "X6_DSCSPA" , "X6_DSCENG" , "X6_DESC1"  , ;
             "X6_DSCSPA1", "X6_DSCENG1", "X6_DESC2"  , "X6_DSCSPA2", "X6_DSCENG2", "X6_CONTEUD", "X6_CONTSPA", ;
             "X6_CONTENG", "X6_PROPRI" , "X6_VALID"  , "X6_INIT"   , "X6_DEFPOR" , "X6_DEFSPA" , "X6_DEFENG" , ;
             "X6_PYME"   }

//
// Atualizando dicionário
//
oProcess:SetRegua2( Len( aSX6 ) )

dbSelectArea( "SX6" )
dbSetOrder( 1 )

For nI := 1 To Len( aSX6 )
	lContinua := .F.
	lReclock  := .F.

	If !SX6->( dbSeek( PadR( aSX6[nI][1], nTamFil ) + PadR( aSX6[nI][2], nTamVar ) ) )
		lContinua := .T.
		lReclock  := .T.
		AutoGrLog( "Foi incluído o parâmetro " + aSX6[nI][1] + aSX6[nI][2] + " Conteúdo [" + AllTrim( aSX6[nI][13] ) + "]" )
	Else
		lContinua := .T.
		lReclock  := .F.
		AutoGrLog( "Foi alterado o parâmetro " + aSX6[nI][1] + aSX6[nI][2] + " de [" + ;
		AllTrim( SX6->X6_CONTEUD ) + "]" + " para [" + AllTrim( aSX6[nI][13] ) + "]" )
	EndIf

	If lContinua
		If !( aSX6[nI][1] $ cAlias )
			cAlias += aSX6[nI][1] + "/"
		EndIf

		RecLock( "SX6", lReclock )
		For nJ := 1 To Len( aSX6[nI] )
			If FieldPos( aEstrut[nJ] ) > 0
				FieldPut( FieldPos( aEstrut[nJ] ), aSX6[nI][nJ] )
			EndIf
		Next nJ
		dbCommit()
		MsUnLock()
	EndIf

	oProcess:IncRegua2( "Atualizando Arquivos (SX6) ..." )

Next nI

AutoGrLog( CRLF + "Final da Atualização" + " SX6" + CRLF + Replicate( "-", 128 ) + CRLF )

Return NIL


//--------------------------------------------------------------------
/*/{Protheus.doc} FSAtuSX7

Função de processamento da gravação do SX7 - Gatilhos

@author UPDATE gerado automaticamente
@since  02/05/2023
@obs    Gerado por EXPORDIC - V.7.5.2.2 EFS / Upd. V.5.3.1 EFS
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function FSAtuSX7()
Local aEstrut   := {}
Local aAreaSX3  := SX3->( GetArea() )
Local aSX7      := {}
*Local cAlias    := ""
Local nI        := 0
Local nJ        := 0
Local nTamSeek  := Len( SX7->X7_CAMPO )

AutoGrLog( "Ínicio da Atualização" + " SX7" + CRLF )

aEstrut := { "X7_CAMPO", "X7_SEQUENC", "X7_REGRA", "X7_CDOMIN", "X7_TIPO", "X7_SEEK", ;
             "X7_ALIAS", "X7_ORDEM"  , "X7_CHAVE", "X7_PROPRI", "X7_CONDIC" }

aAdd( aSX7, {'RA4_CURSO','003','uRA4CustomTrigger():RA4CURSOX7Regra("RA4_DESC")','RA4_DESCCU','P','S','RA1',1,'uRA4CustomTrigger():RA4CURSOX7Chave()','U','URA4CUSTOMTRIGGER():RA4CURSOX7CONDIC()'} )
aAdd( aSX7, {'RA4_CURSO','004','uRA4CustomTrigger():RA4CURSOX7Regra("RA4_DURACA")','RA4_DURACA','P','S','RA1',1,'uRA4CustomTrigger():RA4CURSOX7Chave()','U','URA4CUSTOMTRIGGER():RA4CURSOX7CONDIC()'} )
aAdd( aSX7, {'RA4_CURSO','005','uRA4CustomTrigger():RA4CURSOX7Regra("RA4_UNDURA")','RA4_UNDURA','P','S','RA1',1,'uRA4CustomTrigger():RA4CURSOX7Chave()','U','URA4CUSTOMTRIGGER():RA4CURSOX7CONDIC()'} )
aAdd( aSX7, {'RA4_CURSO','006','uRA4CustomTrigger():RA4CURSOX7Regra("RA4_HORAS")','RA4_HORAS','P','S','RA1',1,'uRA4CustomTrigger():RA4CURSOX7Chave()','U','URA4CUSTOMTRIGGER():RA4CURSOX7CONDIC()'} )
aAdd( aSX7, {'RA4_ENTIDA','001','uRA4CustomTrigger():RA4ENTIDAX7Regra()','RA4_DESCEN','P','S','RA0',1,'uRA4CustomTrigger():RA4ENTIDAX7Chave()','U','URA4CUSTOMTRIGGER():RA4ENTIDAX7CONDIC()'} )
aAdd( aSX7, {'RA4_MAT','001','uRA4CustomTrigger():RA4MatX7Regra()','RA4_NOME','E','S','SRA',1,'uRA4CustomTrigger():RA4MatX7Chave()','U','uRA4CustomTrigger():RA4MatX7Condic()'} )
aAdd( aSX7, {'RA4_ULIDER','001','uRA4CustomTrigger():RA4ULIDERX7Regra()','RA4_UNOMEL','P','N','RD0',1,'uRA4CustomTrigger():RA4ULIDERX7Chave()','U','URA4CUSTOMTRIGGER():RA4ULIDERX7CONDIC()'} )

aAdd( aSX7, {'RA6_CURSO','001','uRA6CustomTrigger():RA6CURSOX7Regra("RA6_DESC")','RA6_DESC','P','S','RA1',1,'uRA6CustomTrigger():RA6CURSOX7Chave()','U','URA6CUSTOMTRIGGER():RA6CURSOX7CONDIC()'} )
aAdd( aSX7, {'RA6_CURSO','002','uRA6CustomTrigger():RA6CURSOX7Regra("RA6_DURACA")','RA6_DURACA','P','S','RA1',1,'uRA6CustomTrigger():RA6CURSOX7Chave()','U','URA6CUSTOMTRIGGER():RA6CURSOX7CONDIC()'} )
aAdd( aSX7, {'RA6_CURSO','003','uRA6CustomTrigger():RA6CURSOX7Regra("RA6_UNID")','RA6_UNID','P','S','RA1',1,'uRA6CustomTrigger():RA6CURSOX7Chave()','U','URA6CUSTOMTRIGGER():RA6CURSOX7CONDIC()'} )
aAdd( aSX7, {'RA6_CURSO','004','uRA6CustomTrigger():RA6CURSOX7Regra("RA6_VALOR")','RA6_VALOR','P','S','RA1',1,'uRA6CustomTrigger():RA6CURSOX7Chave()','U','URA6CUSTOMTRIGGER():RA6CURSOX7CONDIC()'} )
aAdd( aSX7, {'RA6_CURSO','005','uRA6CustomTrigger():RA6CURSOX7Regra("RA6_DTCOTA")','RA6_DTCOTA','P','S','RA1',1,'uRA6CustomTrigger():RA6CURSOX7Chave()','U','URA6CUSTOMTRIGGER():RA6CURSOX7CONDIC()'} )
//
// Atualizando dicionário
//
oProcess:SetRegua2( Len( aSX7 ) )

dbSelectArea( "SX3" )
dbSetOrder( 2 )

dbSelectArea( "SX7" )
dbSetOrder( 1 )

For nI := 1 To Len( aSX7 )

	If !SX7->( dbSeek( PadR( aSX7[nI][1], nTamSeek ) + aSX7[nI][2] ) )

		AutoGrLog( "Foi incluído o gatilho " + aSX7[nI][1] + "/" + aSX7[nI][2] )

		RecLock( "SX7", .T. )
	Else

		AutoGrLog( "Foi alterado o gatilho " + aSX7[nI][1] + "/" + aSX7[nI][2] )

		RecLock( "SX7", .F. )
	EndIf

	For nJ := 1 To Len( aSX7[nI] )
		If FieldPos( aEstrut[nJ] ) > 0
			FieldPut( FieldPos( aEstrut[nJ] ), aSX7[nI][nJ] )
		EndIf
	Next nJ

	dbCommit()
	MsUnLock()

	If SX3->( dbSeek( SX7->X7_CAMPO ) )
		RecLock( "SX3", .F. )
		SX3->X3_TRIGGER := "S"
		MsUnLock()
	EndIf

	oProcess:IncRegua2( "Atualizando Arquivos (SX7) ..." )

Next nI

RestArea( aAreaSX3 )

AutoGrLog( CRLF + "Final da Atualização" + " SX7" + CRLF + Replicate( "-", 128 ) + CRLF )

Return NIL

//--------------------------------------------------------------------
/*/{Protheus.doc} FSAtuSXB

Função de processamento da gravação do SXB - Consultas Padrao

@author UPDATE gerado automaticamente
@since  04/05/2023
@obs    Gerado por EXPORDIC - V.7.5.2.2 EFS / Upd. V.5.3.1 EFS
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function FSAtuSXB()
Local aEstrut   := {}
Local aSXB      := {}
Local cAlias    := ""
Local nI        := 0
Local nJ        := 0

AutoGrLog( "Ínicio da Atualização" + " SXB" + CRLF )

aEstrut := { "XB_ALIAS"  , "XB_TIPO"   , "XB_SEQ"    , "XB_COLUNA" , "XB_DESCRI" , "XB_DESCSPA", "XB_DESCENG", ;
             "XB_WCONTEM", "XB_CONTEM" }

aAdd( aSXB, {'U__RA1','1','01','DB','Curso Int Por Cat','Curso Int Por Cat','Int Course Per Cat','','RA1'} )
aAdd( aSXB, {'U__RA1','2','01','01','Cod. curso','Cód. Curso','Course Code','',''} )
aAdd( aSXB, {'U__RA1','2','02','02','Descricao','Descripción','Description','',''} )
aAdd( aSXB, {'U__RA1','2','03','03','Tp Curso Int + Curso','Tp Curso Int + Curso','Course Int Tp+Course','',''} )
aAdd( aSXB, {'U__RA1','3','01','01','Cadastra Novo','Incluye Nuevo','Add New','','01'} )
aAdd( aSXB, {'U__RA1','4','01','01','Filial','Sucursal','Branch','','RA1_FILIAL'} )
aAdd( aSXB, {'U__RA1','4','01','02','Cod. Curso','Cód. Curso','Course Code','','RA1_CURSO'} )
aAdd( aSXB, {'U__RA1','4','01','03','Descrição','Descripción','Description','','RA1_DESC'} )
aAdd( aSXB, {'U__RA1','4','01','04','Tp Curso Int','Tp Curso Int','Int Course Tp','','RA1_TIPOPP'} )
aAdd( aSXB, {'U__RA1','4','01','05','Categoria','Categoría','Category','','RA1_CATEG'} )
aAdd( aSXB, {'U__RA1','4','02','01','Filial','Sucursal','Branch','','RA1_FILIAL'} )
aAdd( aSXB, {'U__RA1','4','02','02','Cod. Curso','Cód. Curso','Course Code','','RA1_CURSO'} )
aAdd( aSXB, {'U__RA1','4','02','03','Descrição','Descripción','Description','','RA1_DESC'} )
aAdd( aSXB, {'U__RA1','4','02','04','Tp Curso Int','Tp Curso Int','Int Course Tp','','RA1_TIPOPP'} )
aAdd( aSXB, {'U__RA1','4','02','05','Categoria','Categoría','Category','','RA1_CATEG'} )
aAdd( aSXB, {'U__RA1','4','03','01','Filial','Sucursal','Branch','','RA1_FILIAL'} )
aAdd( aSXB, {'U__RA1','4','03','02','Cod. Curso','Cód. Curso','Course Code','','RA1_CURSO'} )
aAdd( aSXB, {'U__RA1','4','03','03','Descrição','Descripción','Description','','RA1_DESC'} )
aAdd( aSXB, {'U__RA1','4','03','04','Tp Curso Int','Tp Curso Int','Int Course Tp','','RA1_TIPOPP'} )
aAdd( aSXB, {'U__RA1','4','03','05','Categoria','Categoría','Category','','RA1_CATEG'} )
aAdd( aSXB, {'U__RA1','5','01','','','','','','RA1->RA1_CURSO'} )
aAdd( aSXB, {'U__RA1','5','02','','','','','','RA1->RA1_DESC'} )
aAdd( aSXB, {'U__RA1','6','01','','','','','','@#u_RA1SXBFilter()'} )

aAdd( aSXB, {'U__RA6','1','01','DB','Entidade','Entidad','Entity','','RA6'} )
aAdd( aSXB, {'U__RA6','2','01','01','Codigo','Codigo','Code','',''} )
aAdd( aSXB, {'U__RA6','3','01','01','Cadastra Novo','Incluye Nuevo','Add New','','01'} )
aAdd( aSXB, {'U__RA6','4','01','01','Codigo','Codigo','Code','','RA6->RA6_ENTIDA'} )
aAdd( aSXB, {'U__RA6','4','01','02','Descricao Entidade','Descripcion','Descripcion','','POSICIONE("RA0",1,xFilial("RA0")+RA6->RA6_ENTIDA,"RA0->RA0_DESC")'} )
aAdd( aSXB, {'U__RA6','4','01','03','Cod.Curso','Curso','Course Code','','RA6_CURSO'} )
aAdd( aSXB, {'U__RA6','4','01','04','Descrição do Curso','Descrição do Curso','Descrição do Curso','','POSICIONE("RA1",1,xFilial("RA1")+RA6->RA6_CURSO,"RA1->RA1_DESC")'} )
aAdd( aSXB, {'U__RA6','5','01','','','','','','RA6->RA6_ENTIDA'} )
aAdd( aSXB, {'U__RA6','5','02','','','','','','POSICIONE("RA0",1,xFilial("RA0")+RA6->RA6_ENTIDA,"RA0->RA0_DESC")'} )
aAdd( aSXB, {'U__RA6','6','01','','','','','','@#u_RA6SXBFilter()'} )

aAdd( aSXB, {'U__RD0','1','01','DB','Cad. Particip.','Regis. Particip.','Participant Register','','RD0'} )
aAdd( aSXB, {'U__RD0','2','01','01','Codigo','Código','Code','',''} )
aAdd( aSXB, {'U__RD0','2','02','02','Nome','Nombre','Name','',''} )
aAdd( aSXB, {'U__RD0','3','01','01','Cadastra Novo','Incluye Nuevo','Add New','','01#Apda020Inc#Apda020Vis("RD0",RD0->(RECNO()))'} )
aAdd( aSXB, {'U__RD0','4','01','01','Codigo Participante','Código Participante','Participant Code','','RD0->RD0_CODIGO'} )
aAdd( aSXB, {'U__RD0','4','01','02','Nome do Participante','Nombre Participante','Participant Name','','RD0->RD0_NOME'} )
aAdd( aSXB, {'U__RD0','4','02','03','Nome do Participante','Nombre Participante','Participant Name','','RD0->RD0_NOME'} )
aAdd( aSXB, {'U__RD0','4','02','04','Codigo Participante','Código Participante','Participant Code','','RD0->RD0_CODIGO'} )
aAdd( aSXB, {'U__RD0','5','01','','','','','','RD0->RD0_CODIGO'} )
aAdd( aSXB, {'U__RD0','5','02','','','','','','RD0->RD0_NOME'} )
aAdd( aSXB, {'U__RD0','6','01','','','','','','@#RdbSxbFilt()'} )

//
// Atualizando dicionário
//
oProcess:SetRegua2( Len( aSXB ) )

dbSelectArea( "SXB" )
dbSetOrder( 1 )

For nI := 1 To Len( aSXB )

	If !Empty( aSXB[nI][1] )

		If !SXB->( dbSeek( PadR( aSXB[nI][1], Len( SXB->XB_ALIAS ) ) + aSXB[nI][2] + aSXB[nI][3] + aSXB[nI][4] ) )

			If !( aSXB[nI][1] $ cAlias )
				cAlias += aSXB[nI][1] + "/"
				AutoGrLog( "Foi incluída a consulta padrão " + aSXB[nI][1] )
			EndIf

			RecLock( "SXB", .T. )

			For nJ := 1 To Len( aSXB[nI] )
				If FieldPos( aEstrut[nJ] ) > 0
					FieldPut( FieldPos( aEstrut[nJ] ), aSXB[nI][nJ] )
				EndIf
			Next nJ

			dbCommit()
			MsUnLock()

		Else

			//
			// Verifica todos os campos
			//
			For nJ := 1 To Len( aSXB[nI] )

				//
				// Se o campo estiver diferente da estrutura
				//
				If !StrTran( AllToChar( SXB->( FieldGet( FieldPos( aEstrut[nJ] ) ) ) ), " ", "" ) == ;
					StrTran( AllToChar( aSXB[nI][nJ] ), " ", "" )

					RecLock( "SXB", .F. )
					FieldPut( FieldPos( aEstrut[nJ] ), aSXB[nI][nJ] )
					dbCommit()
					MsUnLock()

					If !( aSXB[nI][1] $ cAlias )
						cAlias += aSXB[nI][1] + "/"
						AutoGrLog( "Foi alterada a consulta padrão " + aSXB[nI][1] )
					EndIf

				EndIf

			Next

		EndIf

	EndIf

	oProcess:IncRegua2( "Atualizando Consultas Padrões (SXB) ..." )

Next nI

AutoGrLog( CRLF + "Final da Atualização" + " SXB" + CRLF + Replicate( "-", 128 ) + CRLF )

Return NIL


//--------------------------------------------------------------------
/*/{Protheus.doc} FSAtuHlp

Função de processamento da gravação dos Helps de Campos

@author UPDATE gerado automaticamente
@since  02/05/2023
@obs    Gerado por EXPORDIC - V.7.5.2.2 EFS / Upd. V.5.3.1 EFS
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function FSAtuHlp()
Local aHlpPor   := {}
Local aHlpEng   := {}
Local aHlpSpa   := {}

AutoGrLog( "Ínicio da Atualização" + " " + "Helps de Campos" + CRLF )


oProcess:IncRegua2( "Atualizando Helps de Campos ..." )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Código que identifica a filial da' )
aAdd( aHlpPor, 'empresa usuária do sistema.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA1_FILIAL", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA1_FILIAL" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Código do curso.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA1_CURSO ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA1_CURSO" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser informado o código' )
aAdd( aHlpPor, 'do Produto correspondente ao Curso, para' )
aAdd( aHlpPor, 'amarração de Produto x Fornecedor' )
aAdd( aHlpPor, 'quando quiser gerar Cotação de' )
aAdd( aHlpPor, 'treinamento (Integração com módulo de' )
aAdd( aHlpPor, 'Compras).' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA1_PROD  ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA1_PROD" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Descrição do curso.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA1_DESC  ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA1_DESC" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo pode ser digitado:' )
aAdd( aHlpPor, 'Tipo do curso' )
aAdd( aHlpPor, 'Ex.: "C"=Curso.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA1_TIPO  ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA1_TIPO" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Area do curso.' )
aAdd( aHlpPor, 'Ex.: "001" = Area Tecnica.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA1_AREA  ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA1_AREA" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'A duração do Curso.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA1_DURACA", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA1_DURACA" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Unidade de duração do curso.' )
aAdd( aHlpPor, 'Ex.: "M" - Mes.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA1_UNDURA", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA1_UNDURA" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Valor do curso.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA1_VALOR ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA1_VALOR" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'A duração em Horas do curso.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA1_HORAS ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA1_HORAS" )

aHlpPor := {}
aAdd( aHlpPor, 'Tipo de curso. Usado para relacionar os' )
aAdd( aHlpPor, 'tipos de curso com os cursos internos.' )
aAdd( aHlpPor, 'Campo feito para ser utilizado pelo' )
aAdd( aHlpPor, 'portal Rh.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA1_TIPOPP", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA1_TIPOPP" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser informado: o item' )
aAdd( aHlpPor, 'do grupo de curso de acordo com o código' )
aAdd( aHlpPor, 'informado no campo Tp.Curso Ext -' )
aAdd( aHlpPor, 'RA1_TIPOPP. Campo criado para ser' )
aAdd( aHlpPor, 'utilizado pelo portal Rh.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA1_GRUPO ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA1_GRUPO" )

aHlpPor := {}
aAdd( aHlpPor, 'Informe neste campo a quantidade minima' )
aAdd( aHlpPor, 'de participantes para se formar uma' )
aAdd( aHlpPor, 'turma para este curso.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA1_QTDMIN", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA1_QTDMIN" )

aHlpPor := {}
aAdd( aHlpPor, 'Informe se deseja que este curso seja' )
aAdd( aHlpPor, 'impresso na ficha de registro do' )
aAdd( aHlpPor, 'funcionário: 1= Sim; 2 = Não.' )

aHlpEng := {}
aAdd( aHlpEng, 'Enter whether to print this course in' )
aAdd( aHlpEng, 'the employee record file: 1= Yes; 2 =' )
aAdd( aHlpEng, 'No.' )

aHlpSpa := {}
aAdd( aHlpSpa, 'Informe si desea que este curso se' )
aAdd( aHlpSpa, 'imprima en la ficha de registro del' )
aAdd( aHlpSpa, 'empleado: 1 = Si; 2 = No.' )

PutSX1Help( "PRA1_IMPRIM", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA1_IMPRIM" )

aHlpPor := {}
aAdd( aHlpPor, 'Categoria do Curso' )

aHlpEng := {}
aAdd( aHlpEng, 'Course Category' )

aHlpSpa := {}
aAdd( aHlpSpa, 'Categoría del curso' )

PutSX1Help( "PRA1_CATEG ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA1_CATEG" )

aHlpPor := {}
aAdd( aHlpPor, 'Informe o código referente ao Conjunto' )
aAdd( aHlpPor, 'de Etapas a ser utilizado na montagem do' )
aAdd( aHlpPor, 'checklist para o processo de reciclagem' )
aAdd( aHlpPor, 'do curso.' )

aHlpEng := {}
aAdd( aHlpEng, 'Enter the code referent to the Set of' )
aAdd( aHlpEng, 'Stages to be used when assembling the' )
aAdd( aHlpEng, 'checklist for the course recycling' )
aAdd( aHlpEng, 'process.' )

aHlpSpa := {}
aAdd( aHlpSpa, 'Informe el código referente al conjunto' )
aAdd( aHlpSpa, 'de etapas que se utilizará en el montaje' )
aAdd( aHlpSpa, 'del Checklist para el proceso de' )
aAdd( aHlpSpa, 'reciclaje del curso.' )

PutSX1Help( "PRA1_CJETAP", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA1_CJETAP" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Código que identifica a filial da' )
aAdd( aHlpPor, 'empresa usuária do sistema.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_FILIAL", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_FILIAL" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Matrícula do funcionário.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_MAT   ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_MAT" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Nome do funcionário.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_NOME  ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_NOME" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Código do curso realizado pelo' )
aAdd( aHlpPor, 'funcionário.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_CURSO ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_CURSO" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'A descriç„o do curso do funcio-' )
aAdd( aHlpPor, 'nário.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_DESCCU", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_DESCCU" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'O código do curso sinônimo rela-' )
aAdd( aHlpPor, 'cionado a outras empresas.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_SINONI", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_SINONI" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'A descriç„o do código sinônimo.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_DESCSI", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_DESCSI" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Código da entidade do curso rea-' )
aAdd( aHlpPor, 'lizado pelo funcionário.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_ENTIDA", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_ENTIDA" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'O nome da entidade.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_DESCEN", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_DESCEN" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Validade do curso realizado pelo' )
aAdd( aHlpPor, 'funcionário.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_VALIDA", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_VALIDA" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Nota que o funcionário obteve no' )
aAdd( aHlpPor, 'curso.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_NOTA  ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_NOTA" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Duração do curso realizado pelo' )
aAdd( aHlpPor, 'funcionário.' )
aAdd( aHlpPor, 'Ex.: "001"' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_DURACA", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_DURACA" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Unidade de duração do curso reali-' )
aAdd( aHlpPor, 'zado pelo funcionário.' )
aAdd( aHlpPor, 'Ex.: "M"- Mes' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_UNDURA", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_UNDURA" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Percentual de presença do funcio-' )
aAdd( aHlpPor, 'nario no curso.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_PRESEN", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_PRESEN" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Data de início do curso realizado' )
aAdd( aHlpPor, 'pelo funcionário.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_DATAIN", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_DATAIN" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Data final do curso realizado pelo' )
aAdd( aHlpPor, 'funcionário.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_DATAFI", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_DATAFI" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'Valor do curso realizado pelo' )
aAdd( aHlpPor, 'funcionário.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_VALOR ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_VALOR" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'As horas de treinamento do fun-' )
aAdd( aHlpPor, 'cionário em determinado curso.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_HORAS ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_HORAS" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo será informado:' )
aAdd( aHlpPor, 'Código do calendario do curso' )
aAdd( aHlpPor, 'realizado pelo funcionário.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_CALEND", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_CALEND" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo será informado:' )
aAdd( aHlpPor, 'Sequencia que indica a turma do' )
aAdd( aHlpPor, 'curso realizado pelo funcionário.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_TURMA ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_TURMA" )

aHlpPor := {}
aAdd( aHlpPor, 'Nesse campo deve ser digitado:' )
aAdd( aHlpPor, 'Nota de Eficácia Mínima necessária.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_EFICAC", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_EFICAC" )

aHlpPor := {}
aAdd( aHlpPor, 'Nesse campo deve ser digitado:' )
aAdd( aHlpPor, 'Se o Funcionário foi eficaz no' )
aAdd( aHlpPor, 'Treinamento.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_EFICSN", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_EFICSN" )

aHlpPor := {}
aAdd( aHlpPor, 'Este campo indica a origem do curso:' )
aAdd( aHlpPor, '"1" - Coletivo (Treinamento Coletivo)' )
aAdd( aHlpPor, '" " - Outros' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_TIPO  ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_TIPO" )

aHlpPor := {}
aAdd( aHlpPor, 'Deve ser informado o Nível do' )
aAdd( aHlpPor, 'treinamento realizado.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_NIVEL ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_NIVEL" )

aHlpPor := {}
aAdd( aHlpPor, 'Deve ser informado o Status do' )
aAdd( aHlpPor, 'treinamento.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_STATUS", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_STATUS" )

aHlpPor := {}
aAdd( aHlpPor, 'Data da ultima alteração.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_DTALT ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_DTALT" )

aHlpPor := {}
aAdd( aHlpPor, 'Deve conter o código da mensagem de' )
aAdd( aHlpPor, 'comentário.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_CODCOM", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_CODCOM" )

aHlpPor := {}
aAdd( aHlpPor, 'Conteúdo do comentário.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA4_CONTEU", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_CONTEU" )

aHlpPor := {}
aAdd( aHlpPor, 'Categoria do Curso' )

aHlpEng := {}
aAdd( aHlpEng, 'Course Category' )

aHlpSpa := {}
aAdd( aHlpSpa, 'Categoría del curso' )

PutSX1Help( "PRA4_CATCUR", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_CATCUR" )

aHlpPor := {}
aAdd( aHlpPor, 'Descrição da categoria do curso' )

aHlpEng := {}
aAdd( aHlpEng, 'Description of course category' )

aHlpSpa := {}
aAdd( aHlpSpa, 'Descripción de la categoría del curso' )

PutSX1Help( "PRA4_CATDES", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA4_CATDES" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'A Filial do Sistema.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA6_FILIAL", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA6_FILIAL" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'O código da Entidade que ministra o' )
aAdd( aHlpPor, 'cur-so.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA6_ENTIDA", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA6_ENTIDA" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'O código do Curso.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA6_CURSO ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA6_CURSO" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'A descrição da Entidade/Curso.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA6_DESC  ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA6_DESC" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'A duração do Curso.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA6_DURACA", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA6_DURACA" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'A unidade de duração do curso.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA6_UNID  ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA6_UNID" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'O valor do curso.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA6_VALOR ", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA6_VALOR" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser digitado:' )
aAdd( aHlpPor, 'O Conteudo Programatico do Curso.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA6_CONTEU", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA6_CONTEU" )

aHlpPor := {}
aAdd( aHlpPor, 'Neste campo deve ser informado a Data da' )
aAdd( aHlpPor, 'ultima cotação de preço para este' )
aAdd( aHlpPor, 'treinamento.' )

aHlpEng := {}

aHlpSpa := {}

PutSX1Help( "PRA6_DTCOTA", aHlpPor, aHlpEng, aHlpSpa, .T.,,.T. )
AutoGrLog( "Atualizado o Help do campo " + "RA6_DTCOTA" )

AutoGrLog( CRLF + "Final da Atualização" + " " + "Helps de Campos" + CRLF + Replicate( "-", 128 ) + CRLF )

Return {}


//--------------------------------------------------------------------
/*/{Protheus.doc} EscEmpresa
Função genérica para escolha de Empresa, montada pelo SM0

@return aRet Vetor contendo as seleções feitas.
             Se não for marcada nenhuma o vetor volta vazio

@author Ernani Forastieri
@since  27/09/2004
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function EscEmpresa()

//---------------------------------------------
// Parâmetro  nTipo
// 1 - Monta com Todas Empresas/Filiais
// 2 - Monta só com Empresas
// 3 - Monta só com Filiais de uma Empresa
//
// Parâmetro  aMarcadas
// Vetor com Empresas/Filiais pré marcadas
//
// Parâmetro  cEmpSel
// Empresa que será usada para montar seleção
//---------------------------------------------
Local   aRet      := {}
Local   aSalvAmb  := GetArea()
Local   aSalvSM0  := {}
Local   aVetor    := {}
Local   cMascEmp  := "??"
Local   cVar      := ""
Local   lChk      := .F.
*Local   lOk       := .F.
Local   lTeveMarc := .F.
Local   oNo       := LoadBitmap( GetResources(), "LBNO" )
Local   oOk       := LoadBitmap( GetResources(), "LBOK" )
Local   oDlg, oChkMar, oLbx, oMascEmp, oSay
Local   oButDMar, oButInv, oButMarc, oButOk, oButCanc

Local   aMarcadas := {}


If !MyOpenSm0(.F.)
	Return aRet
EndIf


dbSelectArea( "SM0" )
aSalvSM0 := SM0->( GetArea() )
dbSetOrder( 1 )
dbGoTop()

While !SM0->( EOF() )

	If aScan( aVetor, {|x| x[2] == SM0->M0_CODIGO} ) == 0
		aAdd(  aVetor, { aScan( aMarcadas, {|x| x[1] == SM0->M0_CODIGO .and. x[2] == SM0->M0_CODFIL} ) > 0, SM0->M0_CODIGO, SM0->M0_CODFIL, SM0->M0_NOME, SM0->M0_FILIAL } )
	EndIf

	dbSkip()
End

RestArea( aSalvSM0 )

Define MSDialog  oDlg Title "" From 0, 0 To 280, 395 Pixel

oDlg:cToolTip := "Tela para Múltiplas Seleções de Empresas/Filiais"

oDlg:cTitle   := "Selecione a(s) Empresa(s) para Atualização"

@ 10, 10 Listbox  oLbx Var  cVar Fields Header " ", " ", "Empresa" Size 178, 095 Of oDlg Pixel
oLbx:SetArray(  aVetor )
oLbx:bLine := {|| {IIf( aVetor[oLbx:nAt, 1], oOk, oNo ), ;
aVetor[oLbx:nAt, 2], ;
aVetor[oLbx:nAt, 4]}}
oLbx:BlDblClick := { || aVetor[oLbx:nAt, 1] := !aVetor[oLbx:nAt, 1], VerTodos( aVetor, @lChk, oChkMar ), oChkMar:Refresh(), oLbx:Refresh()}
oLbx:cToolTip   :=  oDlg:cTitle
oLbx:lHScroll   := .F. // NoScroll

@ 112, 10 CheckBox oChkMar Var  lChk Prompt "Todos" Message "Marca / Desmarca"+ CRLF + "Todos" Size 40, 007 Pixel Of oDlg;
on Click MarcaTodos( lChk, @aVetor, oLbx )

// Marca/Desmarca por mascara
@ 113, 51 Say   oSay Prompt "Empresa" Size  40, 08 Of oDlg Pixel
@ 112, 80 MSGet oMascEmp Var  cMascEmp Size  05, 05 Pixel Picture "@!"  Valid (  cMascEmp := StrTran( cMascEmp, " ", "?" ), oMascEmp:Refresh(), .T. ) ;
Message "Máscara Empresa ( ?? )"  Of oDlg
oSay:cToolTip := oMascEmp:cToolTip

@ 128, 10 Button oButInv    Prompt "&Inverter"  Size 32, 12 Pixel Action ( InvSelecao( @aVetor, oLbx ), VerTodos( aVetor, @lChk, oChkMar ) ) ;
Message "Inverter Seleção" Of oDlg
oButInv:SetCss( CSSBOTAO )
@ 128, 50 Button oButMarc   Prompt "&Marcar"    Size 32, 12 Pixel Action ( MarcaMas( oLbx, aVetor, cMascEmp, .T. ), VerTodos( aVetor, @lChk, oChkMar ) ) ;
Message "Marcar usando" + CRLF + "máscara ( ?? )"    Of oDlg
oButMarc:SetCss( CSSBOTAO )
@ 128, 80 Button oButDMar   Prompt "&Desmarcar" Size 32, 12 Pixel Action ( MarcaMas( oLbx, aVetor, cMascEmp, .F. ), VerTodos( aVetor, @lChk, oChkMar ) ) ;
Message "Desmarcar usando" + CRLF + "máscara ( ?? )" Of oDlg
oButDMar:SetCss( CSSBOTAO )
@ 112, 157  Button oButOk   Prompt "Processar"  Size 32, 12 Pixel Action (  RetSelecao( @aRet, aVetor ), IIf( Len( aRet ) > 0, oDlg:End(), MsgStop( "Ao menos um grupo deve ser selecionado", "UPDEXP" ) ) ) ;
Message "Confirma a seleção e efetua" + CRLF + "o processamento" Of oDlg
oButOk:SetCss( CSSBOTAO )
@ 128, 157  Button oButCanc Prompt "Cancelar"   Size 32, 12 Pixel Action ( IIf( lTeveMarc, aRet :=  aMarcadas, .T. ), oDlg:End() ) ;
Message "Cancela o processamento" + CRLF + "e abandona a aplicação" Of oDlg
oButCanc:SetCss( CSSBOTAO )

Activate MSDialog  oDlg Center

RestArea( aSalvAmb )
dbSelectArea( "SM0" )
dbCloseArea()

Return  aRet


//--------------------------------------------------------------------
/*/{Protheus.doc} MarcaTodos
Função auxiliar para marcar/desmarcar todos os ítens do ListBox ativo

@param lMarca  Contéudo para marca .T./.F.
@param aVetor  Vetor do ListBox
@param oLbx    Objeto do ListBox

@author Ernani Forastieri
@since  27/09/2004
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function MarcaTodos( lMarca, aVetor, oLbx )
Local  nI := 0

For nI := 1 To Len( aVetor )
	aVetor[nI][1] := lMarca
Next nI

oLbx:Refresh()

Return NIL


//--------------------------------------------------------------------
/*/{Protheus.doc} InvSelecao
Função auxiliar para inverter a seleção do ListBox ativo

@param aVetor  Vetor do ListBox
@param oLbx    Objeto do ListBox

@author Ernani Forastieri
@since  27/09/2004
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function InvSelecao( aVetor, oLbx )
Local  nI := 0

For nI := 1 To Len( aVetor )
	aVetor[nI][1] := !aVetor[nI][1]
Next nI

oLbx:Refresh()

Return NIL


//--------------------------------------------------------------------
/*/{Protheus.doc} RetSelecao
Função auxiliar que monta o retorno com as seleções

@param aRet    Array que terá o retorno das seleções (é alterado internamente)
@param aVetor  Vetor do ListBox

@author Ernani Forastieri
@since  27/09/2004
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function RetSelecao( aRet, aVetor )
Local  nI    := 0

aRet := {}
For nI := 1 To Len( aVetor )
	If aVetor[nI][1]
		aAdd( aRet, { aVetor[nI][2] , aVetor[nI][3], aVetor[nI][2] +  aVetor[nI][3] } )
	EndIf
Next nI

Return NIL


//--------------------------------------------------------------------
/*/{Protheus.doc} MarcaMas
Função para marcar/desmarcar usando máscaras

@param oLbx     Objeto do ListBox
@param aVetor   Vetor do ListBox
@param cMascEmp Campo com a máscara (???)
@param lMarDes  Marca a ser atribuída .T./.F.

@author Ernani Forastieri
@since  27/09/2004
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function MarcaMas( oLbx, aVetor, cMascEmp, lMarDes )
Local cPos1 := SubStr( cMascEmp, 1, 1 )
Local cPos2 := SubStr( cMascEmp, 2, 1 )
Local nPos  := oLbx:nAt
Local nZ    := 0

For nZ := 1 To Len( aVetor )
	If cPos1 == "?" .or. SubStr( aVetor[nZ][2], 1, 1 ) == cPos1
		If cPos2 == "?" .or. SubStr( aVetor[nZ][2], 2, 1 ) == cPos2
			aVetor[nZ][1] := lMarDes
		EndIf
	EndIf
Next

oLbx:nAt := nPos
oLbx:Refresh()

Return NIL


//--------------------------------------------------------------------
/*/{Protheus.doc} VerTodos
Função auxiliar para verificar se estão todos marcados ou não

@param aVetor   Vetor do ListBox
@param lChk     Marca do CheckBox do marca todos (referncia)
@param oChkMar  Objeto de CheckBox do marca todos

@author Ernani Forastieri
@since  27/09/2004
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function VerTodos( aVetor, lChk, oChkMar )
Local lTTrue := .T.
Local nI     := 0

For nI := 1 To Len( aVetor )
	lTTrue := IIf( !aVetor[nI][1], .F., lTTrue )
Next nI

lChk := IIf( lTTrue, .T., .F. )
oChkMar:Refresh()

Return NIL


//--------------------------------------------------------------------
/*/{Protheus.doc} MyOpenSM0

Função de processamento abertura do SM0 modo exclusivo

@author UPDATE gerado automaticamente
@since  02/05/2023
@obs    Gerado por EXPORDIC - V.7.5.2.2 EFS / Upd. V.5.3.1 EFS
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function MyOpenSM0( lShared )
Local lOpen := .F.
Local nLoop := 0

If FindFunction( "OpenSM0Excl" )
	For nLoop := 1 To 20
		If OpenSM0Excl(,.F.)
			lOpen := .T.
			Exit
		EndIf
		Sleep( 500 )
	Next nLoop
Else
	For nLoop := 1 To 20
		dbUseArea( .T., , "SIGAMAT.EMP", "SM0", lShared, .F. )

		If !Empty( Select( "SM0" ) )
			lOpen := .T.
			dbSetIndex( "SIGAMAT.IND" )
			Exit
		EndIf
		Sleep( 500 )
	Next nLoop
EndIf

If !lOpen
	MsgStop( "Não foi possível a abertura da tabela " + ;
	IIf( lShared, "de empresas (SM0).", "de empresas (SM0) de forma exclusiva." ), "ATENÇÃO" )
EndIf

Return lOpen


//--------------------------------------------------------------------
/*/{Protheus.doc} LeLog

Função de leitura do LOG gerado com limitacao de string

@author UPDATE gerado automaticamente
@since  02/05/2023
@obs    Gerado por EXPORDIC - V.7.5.2.2 EFS / Upd. V.5.3.1 EFS
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function LeLog()
Local cRet  := ""
Local cFile := NomeAutoLog()
Local cAux  := ""

FT_FUSE( cFile )
FT_FGOTOP()

While !FT_FEOF()

	cAux := FT_FREADLN()

	If Len( cRet ) + Len( cAux ) < 1048000
		cRet += cAux + CRLF
	Else
		cRet += CRLF
		cRet += Replicate( "=" , 128 ) + CRLF
		cRet += "Tamanho de exibição maxima do LOG alcançado." + CRLF
		cRet += "LOG Completo no arquivo " + cFile + CRLF
		cRet += Replicate( "=" , 128 ) + CRLF
		Exit
	EndIf

	FT_FSKIP()
End

FT_FUSE()

Return cRet


//--------------------------------------------------------------------
/*/{Protheus.doc} MyIsAdmin

Tela para validação do usuário administrador

@author UPDATE gerado automaticamente
@since  02/05/2023
@obs    Gerado por EXPORDIC - V.7.5.2.2 EFS / Upd. V.5.3.1 EFS
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function  MyIsAdmin()
Local cUserLogin := Space( 50 )
Local cUserPsw   := Space( 50 )
Local lRetorno   := .F.
Local oDlg, oBmp, oPanel, oOk, oCancel

Define MsDialog oDlg From 0, 0 To 135, 305 Title "Login" Pixel of oMainWnd

@  0, 0 BITMAP oBmp RESNAME "APLOGO" Size 65,37 NOBORDER Pixel
oBmp:Align := CONTROL_ALIGN_RIGHT

@  0, 0 MSPanel oPanel Of oDlg
oPanel:Align := CONTROL_ALIGN_ALLCLIENT

@ 05,05 Say "Usuário"    Size 60,07 Of oPanel Pixel
@ 13,05 MSGet cUserLogin Size 80,08 Of oPanel Pixel

@ 28,05 Say "Senha"      Size 53,07 Of oPanel Pixel
@ 36,05 MSGet cUserPsw   Size 80,08 Password Of oPanel Pixel

Define SButton oOk     From 53,27 Type 1 Enable Of oPanel Pixel ;
Action ( lRetorno := VldAdmin( cUserLogin, cUserPsw ), IIf( lRetorno, oDlg:End(), ) )

Define SButton oCancel From 53,57 Type 2 Enable Of oPanel Pixel Action oDlg:End()

Activate MSDialog oDlg Center

If lRetorno .AND. FindFunction( "FWMONITORMSG" )
	FWMonitorMsg( "UPDATE FUNCTION - Logged : " + Alltrim( cUserLogin ) )
EndIf

Return lRetorno


//--------------------------------------------------------------------
/*/{Protheus.doc} VldAdmin

Validação do usuário administrador

@author UPDATE gerado automaticamente
@since  02/05/2023
@obs    Gerado por EXPORDIC - V.7.5.2.2 EFS / Upd. V.5.3.1 EFS
@version 1.0
/*/
//--------------------------------------------------------------------
Static Function VldAdmin( cUserLogin, cUserPsw )
Local lRet := .F.

FWMsgRun(, { || lRet := ( PswAdmin( Alltrim( cUserLogin ), Alltrim( cUserPsw ) ) == 0 ) }, , "Validando ..." )

If !lRet
	ApMsgStop( "Usuário não é administrador." + CRLF + "Apenas administradores podem executar este processo." )
EndIf

Return lRet


/////////////////////////////////////////////////////////////////////////////
