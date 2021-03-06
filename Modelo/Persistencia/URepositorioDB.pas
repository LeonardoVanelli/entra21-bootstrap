unit URepositorioDB;

interface

uses
    SqlExpr
  , URepositorio
  , UEntidade
  ;

type
  TRepositorioDB<T: TENTIDADE, constructor> = class(TInterfacedObject, IRepositorio<T>)
  private
    FEntidadeClasse: TEntidadeClasse;
    FNomeTabela: String;
    FNomeCampoPK: String;
    FNomeGerador: String;
    FNomeEntidade: String;

    //Pede para o generator o proximo ID ao fazer insert
    function RetornaNovoId: Integer;

  protected
    FID: Integer;

  protected
    //Prepara na query o comando SQL para fazer o insert
    procedure PreparaInsercao;
    //Excuta a query de inser��o
    procedure ExecutaInsercao;
    //Prepara na query o comando SQL para fazer o update
    procedure PreparaAtualizacao;
    //Executa a query de atualiza��o
    procedure ExecutaAtualizacao(const ciPK: Integer);
    //Atribui os dados do banco no objeto
    procedure AtribuiDBParaEntidade(const coENTIDADE: T); virtual;
    //Atribui os dados do objeto no banco
    procedure AtribuiEntidadeParaDB(const coENTIDADE: T;
                                    const coSQLQuery: TSQLQuery); virtual;

    //Retorna uma string formada para insert ou update com todos os campos da tabela
    //carregados dinamicamente
    function RetornaParametros(const csFormatacao: String): String;

  public
    constructor Create(const coEntidadeClasse: TEntidadeClasse;
                       const csNomeTabela: String;
                       const csNomeCampoPK: String;
                       const csNomeEntidade: String);

    //Excluir o registro pela PK
    procedure Exclui(const ciPK: Integer);
    //Atualiza o registro com os dados do objeto
    procedure Atualiza(const coENTIDADE: T);
    //Insere um novo registro com os dados do objeto
    procedure Insere(const coENTIDADE: T);

    //Docs TO-DO
    function Retorna(const ciId: Integer): TENTIDADE;
    //Docs TO-DO
    function Achou(const ciPK: Integer): Boolean;

    property NOME_ENTIDADE: String read FNomeEntidade;
  end;

const
  CNT_SELECT_UNIQUE     = 'select * from %s where %s = :%1:s';
  CNT_SELECT_GEN_ID     = 'select gen_id(%s, 1) from RDB$DATABASE';
  CNT_INSERT            = 'insert into %s values (%s)';
  CNT_NOME_GERADOR      = 'gen_%s_%s';
  CNT_UPDATE            = 'update %s set %s where %s = :%2:s';
  CNT_DELETE            = 'delete from %s where %s = :%1:s';

  FLD_METADADOS_NOME_COLUNA = 'column_name';
  FLD_GEN_ID                = 'gen_id';

  //Tem como fazer generico
  CNT_FORMATACAO_INSERT = ':%s, ';
  CNT_FORMATACAO_UPDATE = '%0:s = :%0:s, ';

implementation

uses
    UDM
  , SysUtils
  , DB
  ;

{ TPersisteDB }

constructor TRepositorioDB<T>.Create(const coEntidadeClasse: TEntidadeClasse;
                                     const csNomeTabela: String;
                                     const csNomeCampoPK: String;
                                     const csNomeEntidade: String);
begin
  FEntidadeClasse := coEntidadeClasse;
  FNomeTabela     := csNomeTabela;
  FNomeCampoPK    := csNomeCampoPK;
  FNomeEntidade   := csNomeEntidade;
  FNomeGerador    := Format(CNT_NOME_GERADOR, [csNomeTabela, csNomeCampoPK]);
end;

function TRepositorioDB<T>.Achou(const ciPK: Integer): Boolean;
begin
  dmEntra21.SQLSelect.Close;
  //select *
  //  from 'nome da tabela'
  // where 'campo PK' = :'campo PK'
  dmEntra21.SQLSelect.CommandText := Format(CNT_SELECT_UNIQUE, [FNomeTabela
                                                                 , FNomeCampoPK]);
  dmEntra21.SQLSelect.ParamByName(FNomeCampoPK).AsInteger := ciPK;
  dmEntra21.SQLSelect.Open;

  Result := Not dmEntra21.SQLSelect.Eof;
end;

procedure TRepositorioDB<T>.Exclui(const ciPK: Integer);
begin
  dmEntra21.ValidaTransacaoAtiva;

  dmEntra21.SQLDelete.Close;
  dmEntra21.SQLDelete.SQL.Clear;
  dmEntra21.SQLDelete.SQL.Add(Format(CNT_DELETE, [FNomeTabela
                                                   , FNomeCampoPK]));
  dmEntra21.SQLDelete.Prepared := True;
  dmEntra21.SQLDelete.ParamByName(FNomeCampoPK).AsInteger := ciPK;
  dmEntra21.SQLDelete.ExecSQL;
end;

procedure TRepositorioDB<T>.ExecutaAtualizacao(const ciPK: Integer);
begin
  dmEntra21.SQLUpdate.ParamByName(FNomeCampoPK).AsInteger := ciPK;
  dmEntra21.SQLUpdate.ExecSQL;
end;

procedure TRepositorioDB<T>.ExecutaInsercao;
begin
  dmEntra21.SQLInsert.ExecSQL;
end;

procedure TRepositorioDB<T>.PreparaAtualizacao;
begin
  dmEntra21.SQLUpdate.Close;

  //update 'nome da tabela'
  //   set 'nome dos campos'
  // where 'campo PK' = :'campo PK'
  dmEntra21.SQLUpdate.SQL.Clear;
  dmEntra21.SQLUpdate.SQL.Add(Format(CNT_UPDATE, [FNomeTabela
                                                , RetornaParametros(CNT_FORMATACAO_UPDATE)
                                                , FNomeCampoPK]));
  dmEntra21.SQLUpdate.Prepared := True;
end;

procedure TRepositorioDB<T>.PreparaInsercao;
begin
  FID := RetornaNovoId;

  //insert into 'nome da tabela' values ('valores dos campos')
  dmEntra21.SQLInsert.Close;
  dmEntra21.SQLInsert.SQL.Clear;
  dmEntra21.SQLInsert.SQL.Add(Format(CNT_INSERT, [FNomeTabela
                                                   , RetornaParametros(CNT_FORMATACAO_INSERT)
                                                   , FNomeCampoPK]));
  dmEntra21.SQLInsert.Prepared := True;
end;

function TRepositorioDB<T>.RetornaParametros(const csFormatacao: String): String;
var
  lsNomeCampo: String;
  loCampo: TField;
begin
  Result := EmptyStr;

  dmEntra21.SQLTable.GetMetadata := True;
  dmEntra21.SQLTable.TableName := FNomeTabela;
  dmEntra21.SQLTable.Active := True;

  for loCampo in dmEntra21.SQLTable.Fields do
    begin
      lsNomeCampo := loCampo.FieldName;
      Result      := Result + Format(csFormatacao, [lsNomeCampo]);
    end;

  Result := Copy(Result, 1, Length(Result) -2);
end;

function TRepositorioDB<T>.RetornaNovoId: Integer;
begin
  dmEntra21.SQLSelect.Close;
  dmEntra21.SQLSelect.CommandText := Format(CNT_SELECT_GEN_ID, [FNomeGerador]);
  dmEntra21.SQLSelect.Open;

  Result := dmEntra21.SQLSelect.FieldByName(FLD_GEN_ID).AsInteger;
end;

procedure TRepositorioDB<T>.Insere(const coENTIDADE: T);
begin
  PreparaInsercao;
  AtribuiEntidadeParaDB(coENTIDADE, dmEntra21.SQLInsert);
  ExecutaInsercao;

  coENTIDADE.ID := FID;
end;

procedure TRepositorioDB<T>.AtribuiDBParaEntidade(const coENTIDADE: T);
begin
  coENTIDADE.ID := dmEntra21.SQLSelect.FieldByName(FLD_ENTIDADE_ID).AsInteger;
end;

procedure TRepositorioDB<T>.AtribuiEntidadeParaDB(const coENTIDADE: T;
                                                  const coSQLQuery: TSQLQuery);
begin
  coSQLQuery.ParamByName(FLD_ENTIDADE_ID).AsInteger := FID;
end;

procedure TRepositorioDB<T>.Atualiza(const coENTIDADE: T);
begin
  FID := coENTIDADE.ID;

  PreparaAtualizacao;
  AtribuiEntidadeParaDB(coENTIDADE, dmEntra21.SQLUpdate);
  ExecutaAtualizacao(coENTIDADE.ID);
end;

function TRepositorioDB<T>.Retorna(const ciId: Integer): TENTIDADE;
begin
  Result := nil;
  if Achou(ciId) then
    begin
      Result := FEntidadeClasse.Create;
      AtribuiDBParaEntidade(Result);
    end;
end;

end.
