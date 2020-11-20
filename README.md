# MoneyMoney Web Banking Extension for Qonto

[MoneyMoney](https://moneymoney-app.com/) is a user-friendly banking application for macOS.

[Qonto](https://app.qonto.com/) is a French neobank for freelancers and SMEs.

## Installation

* Install a [Beta](https://moneymoney-app.com/beta/) version of MoneyMoney.
* Deactivate the signature validation (»MoneyMoney« → »Preferences« → »Extensions« → »Verify digital signatures of extensions«), because the script is not signed. This is actually not recommended because you have to trust the script unconditionally. Therefore, please check the script yourself beforehand.
* Copy `qonto.lua` to `~/Library/Containers/com.moneymoney-app.retail/Data/Library/Application Support/MoneyMoney/Extensions`.
* Start or restart MoneyMoney.

## Configuration

* Retrieve your API login and secret key via the Qonto web portal → »Settings« → »Integrations (API)«.
* Create a new account of type "Qonto API" in MoneyMoney.
* Use the "Login" as username and the "Secret Key" as password.
