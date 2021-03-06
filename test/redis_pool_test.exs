defmodule RedisPoolTest do
  use ExUnit.Case, async: true
  alias RedisPool, as: R

  setup do
    {:ok, _} = R.create_pool(:default, 10)
    case R.q {:global, :default}, ["FLUSHDB"] do
      {:ok, _} -> :ok
      _ -> :error
    end
  end

  teardown do
    case R.delete_pool(:default) do
      :ok -> :ok
      _ -> :error
    end
  end

  test "work default pool" do
    assert {:ok, :undefined} == R.q {:global, :default}, ["GET", "test"]
    assert {:ok, "OK"} == R.q {:global, :default}, ["SET", "test", "1"]
    assert {:ok, "1"} == R.q {:global, :default}, ["GET", "test"]
  end

  test "work with new pool" do
    assert {:ok, _} = R.create_pool(:new_pool, 2)
    assert {:ok, :undefined} == R.q {:global, :new_pool}, ["GET", "test2"]
    assert {:ok, "OK"} == R.q {:global, :new_pool}, ["SET", "test2", "2"]
    assert {:ok, "2"} == R.q {:global, :new_pool}, ["GET", "test2"]
    assert :ok = R.delete_pool(:new_pool)
  end

  test "error if use invalid commands" do
    assert {:error, "ERR wrong number of arguments for 'set' command"} == R.q {:global, :default}, ["SET", "test3"]
    assert {:error, "ERR wrong number of arguments for 'get' command"} == R.q {:global, :default}, ["GET", "test3", "asdasd"]
  end

  test "transaction success" do
    assert {:ok, :undefined} == R.q {:global, :default}, ["GET", "test4"]
    assert {:ok, :undefined} == R.q {:global, :default}, ["GET", "test4.1"]
    R.transaction {:global, :default}, fn(redis) ->
      :eredis.q redis, ["SET", "test4", "1"]
      :eredis.q redis, ["SET", "test4.1", "2"]
    end
    assert {:ok, "1"} == R.q {:global, :default}, ["GET", "test4"]
    assert {:ok, "2"} == R.q {:global, :default}, ["GET", "test4.1"]
  end

  test "transaction rollback" do
    assert {:ok, :undefined} == R.q {:global, :default}, ["GET", "test5"]
    assert {:ok, :undefined} == R.q {:global, :default}, ["GET", "test5.1"]
    R.transaction {:global, :default}, fn(redis) ->
      :eredis.q redis, ["SET", "test5", "1"] # valid command
      :eredis.q redis, ["SET"] # invalid command
    end
    assert {:ok, :undefined} == R.q {:global, :default}, ["GET", "test5"]
    assert {:ok, :undefined} == R.q {:global, :default}, ["GET", "test5.1"]
  end

  test "ttl works" do
    assert {:ok, "OK"} == R.q {:global, :default}, ["SET", "test6", "1"]
    assert {:ok, "-1"} == R.q {:global, :default}, ["TTL", "test6"]
  end

  test "expire works" do
    R.transaction {:global, :default}, fn(redis) ->
      :eredis.q redis, ["SET", "test7", "1"]
      :eredis.q redis, ["EXPIRE", "test7", "3"]
    end
    {:ok, res} = R.q {:global, :default}, ["TTL", "test7"]
    assert 2 <= res
  end

end
