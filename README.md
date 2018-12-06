# brxTransWrapper
Hi all!
This is a component which may be used to ease usage of code by reducing the code for transactions. 
It works like a wrapper. It adds code for start transactions, commit, rollbacks, fills up memory table.

Here is one example:
This is the original code which I was using for a long time

DataModule1.fdtGlobal.StartTransaction;
try
  with DataModule1.fdqGlobal do
  begin
    close;
    sql.Clear;
    sql.Add('delete from foobar where foo=:P1 and bar=:P2');
    ParamByName('P1').Value := 'foo';
    ParamByName('P2').Value := 'bar';
    ExecSQL;
  end;
  DataModule1.fdtGlobal.Commit;
 except
  DataModule1.fdtGlobal.Rollback;
  raise;
 end;

Instead of this long code, you can use component, by calling the ExecQuery procedure and you will get the same result.

DataModule1.brxTransWrapper1.ExecQuery('delete from foobar where foo=:P1 and bar=:P2',['foo','bar']);

Similar is with opening the resultset.
DataModule1.brxTransWrapper1.OpenQuery('select * from foobar where foo=:P1 and bar=:P2',['foo','bar']);

In this procedure, transaction is started, if there is no error, memory table is getting the resultset and the transaction is committed then you can use memory table to navigate through data, for example:

if DataModule1.fdMemTable.fieldbyname('foo').asstring ='foo' then
...
