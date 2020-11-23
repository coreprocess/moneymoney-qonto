--
-- MoneyMoney Web Banking Extension for Qonto
--
-- http://moneymoney-app.com/api/webbanking
-- https://app.qonto.com/
--
--
-- The MIT License
--
-- Copyright 2020 Niklas Salmoukas
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--

WebBanking {
    version = 1.00,
    url = "https://app.qonto.com/",
    services = {"Qonto API"},
    description = "Qonto is a European neobank for freelancers and SMEs."
}

function SupportsBank(protocol, bankCode)
    return protocol == ProtocolWebBanking and bankCode == "Qonto API"
end

local orgSlug = nil
local auth = nil

function InitializeSession(protocol, bankCode, username, username2, password,
                           username3)

    -- save session data
    orgSlug = username
    auth = username .. ":" .. password

    -- try to fetch organization object
    local fetchedOrg = JSON(Connection():request("GET",
                                                 "https://thirdparty.qonto.com/v2/organizations/" ..
                                                     orgSlug, nil, nil, {
        Accept = "application/json",
        Authorization = auth
    })):dictionary()

    local failure = nil

    -- Login OK?
    if (fetchedOrg["organization"] == nil or fetchedOrg["organization"]["slug"] ~= orgSlug) then
        failure = LoginFailed
    end

    -- check for french bank accounts
    if fetchedOrg["organization"] ~= nil then
        for i, fetchedAccount in ipairs(fetchedOrg["organization"]["bank_accounts"]) do
            if fetchedAccount["iban"]:sub(1, 2):upper() == "FR" then
                failure =
                    "Due to export restrictions, French Qonto customers are currently not supported."
            end
        end
    end

    -- Did we fail?
    if failure ~= nil then
        orgSlug = nil
        auth = nil
        return failure
    end
end

function ListAccounts(knownAccounts)

    -- fetch org
    local fetchedOrg = JSON(Connection():request("GET",
                                                 "https://thirdparty.qonto.com/v2/organizations/" ..
                                                     orgSlug, nil, nil, {
        Accept = "application/json",
        Authorization = auth
    })):dictionary()

    -- build list of accounts
    local accounts = {};

    for i, fetchedAccount in ipairs(fetchedOrg["organization"]["bank_accounts"]) do
        accounts[#accounts + 1] = {
            name = fetchedAccount["slug"],
            owner = fetchedOrg["slug"],
            iban = fetchedAccount["iban"],
            bic = fetchedAccount["bic"],
            currency = fetchedAccount["currency"],
            type = AccountTypeGiro
        };
    end

    return accounts;
end

local function strToDate(str)
    if str == nil then return nil end
    local y, m, d = string.match(str, "(%d%d%d%d)-(%d%d)-(%d%d)")
    if d and m and y then
        return os.time {
            year = y,
            month = m,
            day = d,
            hour = 0,
            min = 0,
            sec = 0
        }
    end
end

function RefreshAccount(account, since)

    -- fetch org
    local fetchedOrg = JSON(Connection():request("GET",
                                                 "https://thirdparty.qonto.com/v2/organizations/" ..
                                                     orgSlug, nil, nil, {
        Accept = "application/json",
        Authorization = auth
    })):dictionary()

    -- find account balance and account slug
    local accountSlug = nil
    local balance = nil
    local pendingBalance = nil

    for i, fetchedAccount in ipairs(fetchedOrg["organization"]["bank_accounts"]) do
        if fetchedAccount["iban"] == account["iban"] then
            accountSlug = fetchedAccount["slug"]
            balance = fetchedAccount["balance"]
            pendingBalance = (fetchedAccount["authorized_balance"] -
                                 fetchedAccount["balance"])
        end
    end

    if accountSlug == nil then return "Could not find account." end

    -- fetch transactions
    local transactions = {}
    local nextPage = 1

    while nextPage ~= nil do

        -- fetch page of transactions
        local sinceFilterArg = ""
        if since ~= nil then
            sinceFilterArg = "&updated_at_from=" ..
                                 os.date('%Y-%m-%dT%H:%M:%SZ', since)
        end

        local fetchedTransactions = JSON(
                                        Connection():request("GET",
                                                             "https://thirdparty.qonto.com/v2/transactions?slug=" ..
                                                                 accountSlug ..
                                                                 "&iban=" ..
                                                                 account["iban"] ..
                                                                 sinceFilterArg ..
                                                                 "&status[]=completed&status[]=pending" ..
                                                                 "&per_page=1000&current_page=" ..
                                                                 nextPage, nil,
                                                             nil, {
                Accept = "application/json",
                Authorization = auth
            })):dictionary()

        -- build transaction
        for i, fetchedTransaction in ipairs(fetchedTransactions["transactions"]) do
            local amount = fetchedTransaction["amount"]
            if fetchedTransaction["side"] == "debit" then
                amount = -amount
            end
            transactions[#transactions + 1] =
                {
                    name = fetchedTransaction["label"],
                    amount = amount,
                    currency = fetchedTransaction["currency"],
                    bookingDate = strToDate(fetchedTransaction["emitted_at"]),
                    valueDate = strToDate(fetchedTransaction["settled_at"]),
                    purpose = fetchedTransaction["reference"],
                    batchReference = fetchedTransaction["transaction_id"],
                    booked = (fetchedTransaction["status"] == "completed")
                }
        end

        -- move to next page
        nextPage = fetchedTransactions["meta"]["next_page"]

    end

    -- build result
    return {
        balance = balance,
        pendingBalance = pendingBalance,
        transactions = transactions
    }
end

function EndSession()

    -- reset session data
    orgSlug = nil
    auth = nil

end
