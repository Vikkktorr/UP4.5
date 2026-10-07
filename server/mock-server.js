#!/usr/bin/env node
/**
 * Мок-сервер учебного API «Автосервис».
 *
 * Сделан по образцу мок-сервера «Библиотека» из практической работы 4
 * и реализует тот же контракт: оболочка списка, коды 404/409/422,
 * логическое и физическое удаление, восстановление, множественное удаление.
 * Зависимостей нет — нужен только Node.js 18 или новее.
 *
 *   node server/mock-server.js
 *   node server/mock-server.js --port 8080 --origin http://localhost:5555
 *   node server/mock-server.js --ttl 60          короткий срок жизни токена
 *
 * Данные хранятся в памяти и сбрасываются при перезапуске
 * либо запросом POST /api/__reset
 *
 * Учебные возможности:
 *   ?__delay=1500   задержка ответа в миллисекундах (проверка индикатора загрузки)
 *   ?__fail=500     принудительный код ошибки (проверка обработки ошибок)
 */

'use strict';

const http = require('node:http');
const crypto = require('node:crypto');

// ─────────────────────────── параметры запуска ───────────────────────────

const args = process.argv.slice(2);
function arg(name, fallback) {
  const i = args.indexOf('--' + name);
  return i !== -1 && args[i + 1] ? args[i + 1] : fallback;
}

const PORT = Number(arg('port', 8080));
const ORIGIN = arg('origin', '*');
// Срок жизни токена доступа в секундах. 900 с = 15 минут; --ttl 60 нужен,
// чтобы проверить автоматическое обновление токена, не ожидая четверть часа.
const ACCESS_TTL = Number(arg('ttl', 900));
const REFRESH_TTL = Number(arg('refresh-ttl', 7 * 24 * 3600));

// ─────────────────────────── начальные данные ───────────────────────────
// Перенесены из seed_data.dart практической работы 3. У мастера capacity —
// сколько автомобилей он может вести одновременно (мест в графике).

const SEED = {
  brands: [
    {"id": 1, "name": "Lada", "country": "Россия", "models": ["Granta", "Iskra", "Largus", "Niva Legend", "Niva Travel", "Vesta"]},
    {"id": 2, "name": "Kia", "country": "Южная Корея", "models": ["Ceed", "EV6", "K5", "Rio", "Seltos", "Sportage"]},
    {"id": 3, "name": "Hyundai", "country": "Южная Корея", "models": ["Creta", "Elantra", "Santa Fe", "Solaris", "Tucson"]},
    {"id": 4, "name": "Toyota", "country": "Япония", "models": ["C-HR", "Camry", "Corolla", "Land Cruiser 200", "Prius", "RAV4"]},
    {"id": 5, "name": "Volkswagen", "country": "Германия", "models": ["Golf", "Passat", "Polo", "Tiguan", "Touareg"]},
    {"id": 6, "name": "Škoda", "country": "Чехия", "models": ["Karoq", "Kodiaq", "Octavia", "Rapid"]},
    {"id": 7, "name": "Renault", "country": "Франция", "models": ["Arkana", "Duster", "Kaptur", "Logan", "Sandero"]},
    {"id": 8, "name": "BMW", "country": "Германия", "models": ["320d", "530d", "X3", "X5 xDrive30d"]},
    {"id": 9, "name": "Mercedes-Benz", "country": "Германия", "models": ["C 200", "E 220 d", "GLC 300 e", "GLE 350 d"]},
    {"id": 10, "name": "Haval", "country": "Китай", "models": ["Dargo", "F7", "H6", "Jolion"]},
    {"id": 11, "name": "Chery", "country": "Китай", "models": ["Tiggo 4", "Tiggo 7 Pro", "Tiggo 8 Pro", "Tiggo 9"]},
    {"id": 12, "name": "Geely", "country": "Китай", "models": ["Atlas", "Coolray", "Monjaro", "Tugella"]},
  ],
  clients: [
    {"id": 1, "lastName": "Иванов", "firstName": "Сергей", "middleName": "Петрович", "phone": "+7 (916) 123-45-67", "email": "s.ivanov@mail.ru", "discount": 5, "registeredAt": "2019-03-14", "card": {"number": "AS-001037", "level": "silver", "issuedAt": "2019-03-14", "expiresAt": "2027-03-14", "bonusPoints": 1250}},
    {"id": 2, "lastName": "Смирнова", "firstName": "Ольга", "middleName": "Викторовна", "phone": "+7 (903) 234-56-78", "email": "olga.smirnova@yandex.ru", "discount": 0, "registeredAt": "2020-07-02", "card": {"number": "AS-001074", "level": "standard", "issuedAt": "2020-07-02", "expiresAt": "2028-07-02", "bonusPoints": 340}},
    {"id": 3, "lastName": "Кузнецов", "firstName": "Андрей", "middleName": "Николаевич", "phone": "+7 (925) 345-67-89", "email": "kuznetsov.a@gmail.com", "discount": 10, "registeredAt": "2019-11-21", "card": {"number": "AS-001111", "level": "gold", "issuedAt": "2019-11-21", "expiresAt": "2027-11-21", "bonusPoints": 4800}},
    {"id": 4, "lastName": "Попова", "firstName": "Марина", "middleName": "Сергеевна", "phone": "+7 (985) 456-78-90", "email": "m.popova@mail.ru", "discount": 0, "registeredAt": "2021-02-09", "card": {"number": "AS-001148", "level": "standard", "issuedAt": "2021-02-09", "expiresAt": "2026-02-09", "bonusPoints": 0}},
    {"id": 5, "lastName": "Васильев", "firstName": "Дмитрий", "middleName": "Александрович", "phone": "+7 (926) 567-89-01", "email": "dvasiliev@yandex.ru", "discount": 7, "registeredAt": "2020-05-17", "card": {"number": "AS-001185", "level": "silver", "issuedAt": "2020-05-17", "expiresAt": "2028-05-17", "bonusPoints": 2100}},
    {"id": 6, "lastName": "Петрова", "firstName": "Екатерина", "middleName": "Игоревна", "phone": "+7 (915) 678-90-12", "email": "kate.petrova@gmail.com", "discount": 3, "registeredAt": "2022-09-30", "card": {"number": "AS-001222", "level": "standard", "issuedAt": "2022-09-30", "expiresAt": "2030-09-30", "bonusPoints": 560}},
    {"id": 7, "lastName": "Соколов", "firstName": "Алексей", "middleName": "Владимирович", "phone": "+7 (977) 789-01-23", "email": "sokolov.av@mail.ru", "discount": 15, "registeredAt": "2018-12-05", "card": {"number": "AS-001259", "level": "gold", "issuedAt": "2018-12-05", "expiresAt": "2026-12-05", "bonusPoints": 7300}},
    {"id": 8, "lastName": "Михайлова", "firstName": "Анна", "middleName": "Дмитриевна", "phone": "+7 (999) 890-12-34", "email": "anna.m@yandex.ru", "discount": 0, "registeredAt": "2023-04-11", "card": {"number": "AS-001296", "level": "standard", "issuedAt": "2023-04-11", "expiresAt": "2031-04-11", "bonusPoints": 120}},
    {"id": 9, "lastName": "Новиков", "firstName": "Павел", "middleName": "Юрьевич", "phone": "+7 (916) 901-23-45", "email": "p.novikov@gmail.com", "discount": 5, "registeredAt": "2021-08-23", "card": {"number": "AS-001333", "level": "silver", "issuedAt": "2021-08-23", "expiresAt": "2029-08-23", "bonusPoints": 1900}},
    {"id": 10, "lastName": "Фёдоров", "firstName": "Игорь", "middleName": "Олегович", "phone": "+7 (903) 012-34-56", "email": "fedorov.io@mail.ru", "discount": 0, "registeredAt": "2024-01-19", "card": {"number": "AS-001370", "level": "standard", "issuedAt": "2024-01-19", "expiresAt": "2032-01-19", "bonusPoints": 0}},
    {"id": 11, "lastName": "Морозова", "firstName": "Татьяна", "middleName": "Андреевна", "phone": "+7 (925) 111-22-33", "email": "t.morozova@yandex.ru", "discount": 3, "registeredAt": "2022-03-03", "card": {"number": "AS-001407", "level": "standard", "issuedAt": "2022-03-03", "expiresAt": "2030-03-03", "bonusPoints": 880}},
    {"id": 12, "lastName": "Волков", "firstName": "Никита", "middleName": "Евгеньевич", "phone": "+7 (985) 222-33-44", "email": "volkov.ne@gmail.com", "discount": 0, "registeredAt": "2025-06-12", "card": {"number": "AS-001444", "level": "standard", "issuedAt": "2025-06-12", "expiresAt": "2033-06-12", "bonusPoints": 60}},
    {"id": 13, "lastName": "Алексеева", "firstName": "Юлия", "middleName": "Романовна", "phone": "+7 (926) 333-44-55", "email": "yu.alekseeva@mail.ru", "discount": 0, "registeredAt": "2026-02-27", "card": {"number": "AS-001481", "level": "standard", "issuedAt": "2026-02-27", "expiresAt": "2034-02-27", "bonusPoints": 0}},
    {"id": 14, "lastName": "Лебедев", "firstName": "Максим", "middleName": "Ильич", "phone": "+7 (977) 444-55-66", "email": "m.lebedev@yandex.ru", "discount": 10, "registeredAt": "2020-10-08", "card": {"number": "AS-001518", "level": "gold", "issuedAt": "2020-10-08", "expiresAt": "2028-10-08", "bonusPoints": 3350}},
  ],
  mechanics: [
    {"id": 1, "lastName": "Громов", "firstName": "Виктор", "middleName": "Алексеевич", "phone": "+7 (916) 200-10-01", "grade": 6, "experience": 22, "hiredAt": "2012-04-02", "capacity": 2},
    {"id": 2, "lastName": "Белов", "firstName": "Артём", "middleName": "Сергеевич", "phone": "+7 (916) 200-10-02", "grade": 4, "experience": 9, "hiredAt": "2017-09-11", "capacity": 8},
    {"id": 3, "lastName": "Зайцев", "firstName": "Кирилл", "middleName": "Игоревич", "phone": "+7 (916) 200-10-03", "grade": 5, "experience": 14, "hiredAt": "2014-03-17", "capacity": 8},
    {"id": 4, "lastName": "Орлов", "firstName": "Денис", "middleName": "Павлович", "phone": "+7 (916) 200-10-04", "grade": 3, "experience": 5, "hiredAt": "2021-06-01", "capacity": 8},
    {"id": 5, "lastName": "Ершов", "firstName": "Роман", "middleName": "Викторович", "phone": "+7 (916) 200-10-05", "grade": 5, "experience": 12, "hiredAt": "2015-01-19", "capacity": 8},
    {"id": 6, "lastName": "Титов", "firstName": "Илья", "middleName": "Андреевич", "phone": "+7 (916) 200-10-06", "grade": 2, "experience": 2, "hiredAt": "2024-02-05", "capacity": 8},
    {"id": 7, "lastName": "Карпов", "firstName": "Олег", "middleName": "Николаевич", "phone": "+7 (916) 200-10-07", "grade": 6, "experience": 27, "hiredAt": "2010-08-23", "capacity": 8},
    {"id": 8, "lastName": "Жуков", "firstName": "Степан", "middleName": "Ильич", "phone": "+7 (916) 200-10-08", "grade": 4, "experience": 8, "hiredAt": "2018-10-15", "capacity": 8},
    {"id": 9, "lastName": "Никитин", "firstName": "Глеб", "middleName": "Олегович", "phone": "+7 (916) 200-10-09", "grade": 3, "experience": 4, "hiredAt": "2022-05-30", "capacity": 8},
    {"id": 10, "lastName": "Макаров", "firstName": "Фёдор", "middleName": "Дмитриевич", "phone": "+7 (916) 200-10-10", "grade": 5, "experience": 16, "hiredAt": "2013-11-04", "capacity": 8},
    {"id": 11, "lastName": "Сорокин", "firstName": "Тимур", "middleName": "Русланович", "phone": "+7 (916) 200-10-11", "grade": 4, "experience": 7, "hiredAt": "2019-07-08", "capacity": 8},
    {"id": 12, "lastName": "Руденко", "firstName": "Ярослав", "middleName": "Евгеньевич", "phone": "+7 (916) 200-10-12", "grade": 1, "experience": 1, "hiredAt": "2025-09-01", "capacity": 8},
  ],
  services: [
    {"id": 1, "name": "Замена моторного масла и фильтра", "category": "maintenance", "price": 1800, "duration": 40},
    {"id": 2, "name": "Плановое ТО-1", "category": "maintenance", "price": 6500, "duration": 120},
    {"id": 3, "name": "Плановое ТО-2", "category": "maintenance", "price": 11900, "duration": 210},
    {"id": 4, "name": "Замена воздушного фильтра", "category": "maintenance", "price": 600, "duration": 15},
    {"id": 5, "name": "Компьютерная диагностика двигателя", "category": "engine", "price": 2200, "duration": 45},
    {"id": 6, "name": "Замена ремня ГРМ", "category": "engine", "price": 9800, "duration": 240},
    {"id": 7, "name": "Замена свечей зажигания", "category": "engine", "price": 1500, "duration": 30},
    {"id": 8, "name": "Замена тормозных колодок (ось)", "category": "chassis", "price": 2400, "duration": 60},
    {"id": 9, "name": "Развал-схождение", "category": "chassis", "price": 2900, "duration": 60},
    {"id": 10, "name": "Замена амортизаторов (пара)", "category": "chassis", "price": 5600, "duration": 150},
    {"id": 11, "name": "Диагностика электрооборудования", "category": "electrics", "price": 1900, "duration": 60},
    {"id": 12, "name": "Замена аккумулятора", "category": "electrics", "price": 700, "duration": 20},
    {"id": 13, "name": "Полировка кузова", "category": "body", "price": 8500, "duration": 300},
    {"id": 14, "name": "Покраска детали", "category": "body", "price": 12000, "duration": 480},
    {"id": 15, "name": "Сезонная смена шин", "category": "tires", "price": 2800, "duration": 50},
    {"id": 16, "name": "Балансировка колёс", "category": "tires", "price": 1200, "duration": 30},
  ],
  cars: [
    {"id": 1, "plate": "А123ВС777", "vin": "XTA219170K0123456", "brandId": 1, "model": "Granta", "year": 2019, "mileage": 84500, "fuel": "petrol", "clientId": 1, "mechanicIds": [6, 11], "serviceIds": [3, 4, 14]},
    {"id": 2, "plate": "В456ОР197", "vin": "Z94CB41AAGR323020", "brandId": 3, "model": "Solaris", "year": 2016, "mileage": 142300, "fuel": "petrol", "clientId": 1, "mechanicIds": [6, 11], "serviceIds": [7, 9, 16]},
    {"id": 3, "plate": "Е789КХ77", "vin": "XWEPH81ABK0012345", "brandId": 2, "model": "Rio", "year": 2019, "mileage": 67800, "fuel": "petrol", "clientId": 2, "mechanicIds": [4], "serviceIds": [4, 10, 13]},
    {"id": 4, "plate": "К001МР750", "vin": "JTNB11HK103456789", "brandId": 4, "model": "Camry", "year": 2021, "mileage": 45200, "fuel": "hybrid", "clientId": 3, "mechanicIds": [8, 9], "serviceIds": [13]},
    {"id": 5, "plate": "М250ТТ799", "vin": "XW8ZZZ61ZJG012345", "brandId": 5, "model": "Polo", "year": 2018, "mileage": 98100, "fuel": "petrol", "clientId": 3, "mechanicIds": [2, 3], "serviceIds": [7, 10, 16]},
    {"id": 6, "plate": "Н333АА777", "vin": "TMBJG7NE8K0123456", "brandId": 6, "model": "Octavia", "year": 2019, "mileage": 76400, "fuel": "petrol", "clientId": 4, "mechanicIds": [7], "serviceIds": [3, 4, 5]},
    {"id": 7, "plate": "О777ОО97", "vin": "X7LHSRHGN61234567", "brandId": 7, "model": "Duster", "year": 2020, "mileage": 58900, "fuel": "diesel", "clientId": 5, "mechanicIds": [5, 12], "serviceIds": [1, 6, 16]},
    {"id": 8, "plate": "Р404ЕК199", "vin": "WBA8E9C51GK123456", "brandId": 8, "model": "320d", "year": 2016, "mileage": 156000, "fuel": "diesel", "clientId": 5, "mechanicIds": [5, 12], "serviceIds": [9]},
    {"id": 9, "plate": "С515СС50", "vin": "WDD2130041A123456", "brandId": 9, "model": "E 220 d", "year": 2017, "mileage": 121500, "fuel": "diesel", "clientId": 7, "mechanicIds": [10], "serviceIds": [6, 11, 12]},
    {"id": 10, "plate": "Т909УХ777", "vin": "LGWFF6A59MH123456", "brandId": 10, "model": "Jolion", "year": 2022, "mileage": 31200, "fuel": "petrol", "clientId": 6, "mechanicIds": [2, 3], "serviceIds": [1, 8, 15]},
    {"id": 11, "plate": "У818НВ797", "vin": "LVTDB21B8ND123456", "brandId": 11, "model": "Tiggo 7 Pro", "year": 2022, "mileage": 28700, "fuel": "petrol", "clientId": 8, "mechanicIds": [8, 9], "serviceIds": [2, 5, 12]},
    {"id": 12, "plate": "Х626КМ77", "vin": "L6T7722Z9NU123456", "brandId": 12, "model": "Coolray", "year": 2023, "mileage": 19400, "fuel": "petrol", "clientId": 9, "mechanicIds": [1], "serviceIds": [5]},
    {"id": 13, "plate": "А808АР190", "vin": "XTAGFL110KY234567", "brandId": 1, "model": "Vesta", "year": 2020, "mileage": 61300, "fuel": "gas", "clientId": 10, "mechanicIds": [6, 11], "serviceIds": [2, 8, 15]},
    {"id": 14, "plate": "В212ВВ777", "vin": "XTA212140L1234567", "brandId": 1, "model": "Niva Legend", "year": 2021, "mileage": 38900, "fuel": "petrol", "clientId": 14, "mechanicIds": [6, 11], "serviceIds": [11, 12, 13]},
    {"id": 15, "plate": "Е505ХА799", "vin": "XWEGU411BK0034567", "brandId": 2, "model": "Sportage", "year": 2020, "mileage": 72400, "fuel": "diesel", "clientId": 11, "mechanicIds": [4], "serviceIds": [8, 9, 14]},
    {"id": 16, "plate": "К142КК197", "vin": "Z94K241CBLR123456", "brandId": 3, "model": "Creta", "year": 2021, "mileage": 54600, "fuel": "petrol", "clientId": 12, "mechanicIds": [8, 9], "serviceIds": [1]},
    {"id": 17, "plate": "М990МР50", "vin": "JTMHV05J604567890", "brandId": 4, "model": "Land Cruiser 200", "year": 2015, "mileage": 198700, "fuel": "diesel", "clientId": 7, "mechanicIds": [2, 3], "serviceIds": [3, 4, 14]},
    {"id": 18, "plate": "Н646ОТ777", "vin": "WVWZZZ3CZKE123456", "brandId": 5, "model": "Passat", "year": 2019, "mileage": 88800, "fuel": "petrol", "clientId": 14, "mechanicIds": [7], "serviceIds": [7, 9, 16]},
    {"id": 19, "plate": "О123ХН750", "vin": "TMBAG7NS5L8012345", "brandId": 6, "model": "Kodiaq", "year": 2020, "mileage": 69500, "fuel": "diesel", "clientId": 3, "mechanicIds": [5, 12], "serviceIds": [4, 10, 13]},
    {"id": 20, "plate": "Р777РР77", "vin": "X7LBSRB1H54345678", "brandId": 7, "model": "Logan", "year": 2017, "mileage": 176400, "fuel": "gas", "clientId": 10, "mechanicIds": [4], "serviceIds": [1, 9], "deletedAt": "2026-08-14T00:00:00.000"},
    {"id": 21, "plate": "С404ВА199", "vin": "WBAJA91070B123456", "brandId": 8, "model": "X5 xDrive30d", "year": 2021, "mileage": 47300, "fuel": "diesel", "clientId": 7, "mechanicIds": [10], "serviceIds": [7, 10, 16]},
    {"id": 22, "plate": "Т262ТТ797", "vin": "WDC2539051F234567", "brandId": 9, "model": "GLC 300 e", "year": 2020, "mileage": 63200, "fuel": "hybrid", "clientId": 9, "mechanicIds": [2, 3], "serviceIds": [3, 4, 5]},
    {"id": 23, "plate": "У111УУ777", "vin": "LGWEF4A55NH234567", "brandId": 10, "model": "F7", "year": 2021, "mileage": 52100, "fuel": "petrol", "clientId": 4, "mechanicIds": [8, 9], "serviceIds": [1, 6, 16]},
    {"id": 24, "plate": "Х345ОР190", "vin": "LVVDB21B5MD234567", "brandId": 11, "model": "Tiggo 4", "year": 2021, "mileage": 49800, "fuel": "petrol", "clientId": 12, "mechanicIds": [1], "serviceIds": [9]},
    {"id": 25, "plate": "А456МН797", "vin": "L6T79P2E0NE234567", "brandId": 12, "model": "Monjaro", "year": 2023, "mileage": 15600, "fuel": "petrol", "clientId": 1, "mechanicIds": [6, 11], "serviceIds": [6, 11, 12]},
    {"id": 26, "plate": "В999ХХ77", "vin": "JTDKB20U703456789", "brandId": 4, "model": "Prius", "year": 2014, "mileage": 211300, "fuel": "hybrid", "clientId": 6, "mechanicIds": [6, 11], "serviceIds": [1, 8, 15]},
    {"id": 27, "plate": "Е321ЕЕ750", "vin": "XTA219060N0345678", "brandId": 1, "model": "Largus", "year": 2022, "mileage": 44100, "fuel": "gas", "clientId": 11, "mechanicIds": [4], "serviceIds": [2, 5, 12]},
    {"id": 28, "plate": "К808ТУ777", "vin": "XWEJC813BM0045678", "brandId": 2, "model": "K5", "year": 2022, "mileage": 26800, "fuel": "petrol", "clientId": 8, "mechanicIds": [8, 9], "serviceIds": [5]},
    {"id": 29, "plate": "М616АВ199", "vin": "Z94G2811BMR234567", "brandId": 3, "model": "Tucson", "year": 2022, "mileage": 33500, "fuel": "petrol", "clientId": 14, "mechanicIds": [2, 3], "serviceIds": [2, 8, 15]},
    {"id": 30, "plate": "Н220ВС97", "vin": "WVGZZZ5NZMW234567", "brandId": 5, "model": "Tiguan", "year": 2021, "mileage": 57200, "fuel": "petrol", "clientId": 2, "mechanicIds": [7], "serviceIds": [11, 12, 13]},
    {"id": 31, "plate": "О404КА799", "vin": "KNAC381AFP5012345", "brandId": 2, "model": "EV6", "year": 2023, "mileage": 18900, "fuel": "electric", "clientId": 9, "mechanicIds": [5, 12], "serviceIds": [8, 9, 14]},
    {"id": 32, "plate": "Р135РС77", "vin": "JTNKHMBX0M1234567", "brandId": 4, "model": "C-HR", "year": 2020, "mileage": 48700, "fuel": "hybrid", "clientId": 5, "mechanicIds": [5, 12], "serviceIds": [1]},
    {"id": 33, "plate": "С717СА197", "vin": "X7LASRA1JH6456789", "brandId": 7, "model": "Arkana", "year": 2019, "mileage": 83900, "fuel": "petrol", "clientId": 6, "mechanicIds": [10], "serviceIds": [3, 4, 14]},
    {"id": 34, "plate": "Т050ТН750", "vin": "LVTDB21B0PD345678", "brandId": 11, "model": "Tiggo 8 Pro", "year": 2023, "mileage": 22300, "fuel": "petrol", "clientId": 12, "mechanicIds": [2, 3], "serviceIds": [7, 9, 16]},
  ],
};

// ─────────────────────────────── данные ───────────────────────────────

const COLLECTIONS = ['brands', 'clients', 'mechanics', 'services', 'cars'];

let db;

function seed() {
  const copy = JSON.parse(JSON.stringify(SEED));
  db = { seq: {} };
  db.users = USERS_SEED.map((u) => ({ ...u, password: hashPassword(u.password) }));
  db.seq.users = Math.max(...USERS_SEED.map((u) => u.id));
  for (const collection of COLLECTIONS) {
    db[collection] = copy[collection].map((row) => ({
      ...row,
      createdAt: new Date().toISOString(),
      deletedAt: row.deletedAt ? new Date(row.deletedAt).toISOString() : null,
    }));
    db.seq[collection] = Math.max(0, ...db[collection].map((x) => x.id));
  }
}

function push(collection, obj) {
  db.seq[collection] += 1;
  const row = { id: db.seq[collection], ...obj, createdAt: new Date().toISOString(), deletedAt: null };
  db[collection].push(row);
  return row;
}

// ───────────────────────── пользователи и роли ─────────────────────────
// Роль хранится на сервере и попадает в подписанный токен. Клиент её
// только читает: подменить роль в браузере нельзя — подпись не сойдётся.

const ROLES = { client: 1, mechanic: 2, admin: 3 };

/** Пароль хранится не в открытом виде: соль + scrypt (аналог BCrypt). */
function hashPassword(password, salt = crypto.randomBytes(16).toString('hex')) {
  const hash = crypto.scryptSync(String(password), salt, 32).toString('hex');
  return `${salt}:${hash}`;
}

function verifyPassword(password, stored) {
  const [salt] = String(stored).split(':');
  const expected = Buffer.from(stored, 'utf8');
  const actual = Buffer.from(hashPassword(password, salt), 'utf8');
  return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
}

// Пароли учебных пользователей проходят ту же проверку, что и при
// регистрации: не короче восьми знаков, цифра, специальный символ.
const USERS_SEED = [
  { id: 1, username: 'admin',  password: 'Admin#2026',  role: 'admin',    lastName: 'Казанцев', firstName: 'Виктор',  clientId: null, mechanicId: null },
  { id: 2, username: 'master', password: 'Master#2026', role: 'mechanic', lastName: 'Громов',   firstName: 'Виктор' , clientId: null, mechanicId: 1 },
  { id: 3, username: 'client', password: 'Client#2026', role: 'client',   lastName: 'Иванов',   firstName: 'Сергей',  clientId: 1,    mechanicId: null },
];

// ───────────────────────────────── токены ─────────────────────────────────
// Формат как у JWT: заголовок.данные.подпись, base64url. Ключ живёт только
// на сервере, поэтому изменить роль в токене из браузера невозможно.

const SECRET = crypto.randomBytes(32);

const b64 = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
const sign = (data) => crypto.createHmac('sha256', SECRET).update(data).digest('base64url');

function issueToken(user, type, ttl) {
  const payload = {
    sub: user.id,
    username: user.username,
    role: user.role,
    typ: type,
    exp: Math.floor(Date.now() / 1000) + ttl,
  };
  const head = b64({ alg: 'HS256', typ: 'JWT' });
  const body = b64(payload);
  return `${head}.${body}.${sign(`${head}.${body}`)}`;
}

/** Разбор токена: null, если подпись не сошлась или срок истёк. */
function readToken(token, type) {
  const parts = String(token || '').split('.');
  if (parts.length !== 3) return null;
  const [head, body, signature] = parts;
  // timingSafeEqual требует одинаковой длины буферов.
  const expected = sign(`${head}.${body}`);
  if (expected.length !== signature.length) return null;
  if (!crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature))) return null;
  let payload;
  try {
    payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
  } catch {
    return null;
  }
  if (payload.typ !== type) return null;
  if (payload.exp * 1000 < Date.now()) return null;
  return payload;
}

function publicUser(user) {
  return {
    id: user.id,
    username: user.username,
    role: user.role,
    lastName: user.lastName,
    firstName: user.firstName,
    fullName: [user.lastName, user.firstName].filter(Boolean).join(' '),
    clientId: user.clientId,
    mechanicId: user.mechanicId,
  };
}

function session(user) {
  return {
    accessToken: issueToken(user, 'access', ACCESS_TTL),
    refreshToken: issueToken(user, 'refresh', REFRESH_TTL),
    expiresIn: ACCESS_TTL,
    user: publicUser(user),
  };
}

/** Пользователь из заголовка Authorization: Bearer … либо null. */
function currentUser(req) {
  const header = req.headers.authorization || '';
  if (!header.startsWith('Bearer ')) return null;
  const payload = readToken(header.slice(7).trim(), 'access');
  if (!payload) return null;
  // Роль берётся из таблицы пользователей по идентификатору из токена:
  // если администратор поменял роль, новые права действуют сразу.
  return db.users.find((u) => u.id === payload.sub) || null;
}

const PASSWORD_SPECIAL = /[^A-Za-z0-9]/;

function validatePassword(password) {
  const value = String(password || '');
  if (value.length < 8) return 'Не короче восьми знаков';
  if (!/\d/.test(value)) return 'Добавьте хотя бы одну цифру';
  if (!PASSWORD_SPECIAL.test(value)) return 'Добавьте специальный символ';
  return null;
}

// ─────────────────────────── вспомогательное ───────────────────────────

// Латинские буквы, совпадающие по написанию с буквами госномера.
const LATIN_TO_CYRILLIC = {
  A: 'А', B: 'В', E: 'Е', K: 'К', M: 'М', H: 'Н',
  O: 'О', P: 'Р', C: 'С', T: 'Т', Y: 'У', X: 'Х',
};

function normalizePlate(value) {
  return [...String(value || '').toUpperCase().replace(/\s/g, '')]
    .map((ch) => LATIN_TO_CYRILLIC[ch] || ch)
    .join('');
}

const digitsOnly = (value) => String(value || '').replace(/\D/g, '');
const fullName = (p) => [p.lastName, p.firstName, p.middleName].filter(Boolean).join(' ');

function shortName(p) {
  const initials = [p.firstName, p.middleName].filter(Boolean).map((s) => s[0] + '.').join(' ');
  return initials ? `${p.lastName} ${initials}` : p.lastName;
}

function plural(n, one, few, many) {
  const mod10 = n % 10;
  const mod100 = n % 100;
  if (mod10 === 1 && mod100 !== 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

const find = (collection, id) => db[collection].find((x) => x.id === Number(id));

/** Сколько действующих автомобилей ведёт мастер (не считая автомобиль exceptCarId). */
function mechanicLoad(mechanicId, exceptCarId = null) {
  return db.cars.filter(
    (c) => !c.deletedAt && c.id !== exceptCarId && c.mechanicIds.includes(mechanicId)
  ).length;
}

// ──────────────────────── развёртывание объектов ────────────────────────

/**
 * На запись автомобиль принимает brandId, clientId, mechanicIds, serviceIds,
 * а на чтение отдаёт развёрнутые объекты — как книга в контракте «Библиотеки».
 */
function expandCar(c) {
  const brand = find('brands', c.brandId);
  const client = find('clients', c.clientId);
  return {
    id: c.id,
    plate: c.plate,
    vin: c.vin,
    brand: brand ? { id: brand.id, name: brand.name } : null,
    model: c.model,
    year: c.year,
    mileage: c.mileage,
    fuel: c.fuel,
    client: client ? { id: client.id, fullName: fullName(client) } : null,
    mechanics: c.mechanicIds
      .map((id) => find('mechanics', id))
      .filter(Boolean)
      .map((m) => ({ id: m.id, fullName: shortName(m) })),
    services: c.serviceIds
      .map((id) => find('services', id))
      .filter(Boolean)
      .map((s) => ({ id: s.id, name: s.name })),
    createdAt: c.createdAt,
    deletedAt: c.deletedAt,
  };
}

const EXPANDERS = {
  cars: expandCar,
  clients: (x) => x,
  brands: (x) => x,
  mechanics: (x) => x,
  services: (x) => x,
};

// ─────────────────────────── общие операции ───────────────────────────

function matchesSearch(collection, item, search) {
  const needle = String(search).trim().toLowerCase();
  if (!needle) return true;
  const digits = digitsOnly(needle);
  switch (collection) {
    case 'cars':
      return (
        normalizePlate(item.plate).includes(normalizePlate(needle)) ||
        item.vin.toLowerCase().includes(needle) ||
        item.model.toLowerCase().includes(needle)
      );
    case 'clients':
      // По телефону ищем только по цифрам: «916 123» найдёт «+7 (916) 123-45-67».
      return (
        fullName(item).toLowerCase().includes(needle) ||
        item.email.toLowerCase().includes(needle) ||
        item.card.number.toLowerCase().includes(needle) ||
        (digits.length >= 3 && digitsOnly(item.phone).includes(digits))
      );
    case 'brands':
      return (
        item.name.toLowerCase().includes(needle) ||
        item.models.some((m) => m.toLowerCase().includes(needle))
      );
    case 'mechanics':
      return (
        fullName(item).toLowerCase().includes(needle) ||
        (digits.length >= 3 && digitsOnly(item.phone).includes(digits))
      );
    case 'services':
      return item.name.toLowerCase().includes(needle);
    default:
      return true;
  }
}

function applyFilters(collection, rows, q) {
  let result = rows;
  if (q.search) result = result.filter((x) => matchesSearch(collection, x, q.search));

  if (collection === 'cars') {
    if (q.brandId) result = result.filter((c) => c.brandId === Number(q.brandId));
    if (q.fuel) result = result.filter((c) => c.fuel === q.fuel);
    if (q.yearFrom) result = result.filter((c) => c.year >= Number(q.yearFrom));
    if (q.yearTo) result = result.filter((c) => c.year <= Number(q.yearTo));
    if (q.clientId) result = result.filter((c) => c.clientId === Number(q.clientId));
    if (q.mechanicId) result = result.filter((c) => c.mechanicIds.includes(Number(q.mechanicId)));
    if (q.serviceId) result = result.filter((c) => c.serviceIds.includes(Number(q.serviceId)));
  }
  if (collection === 'clients' && q.level) result = result.filter((c) => c.card.level === q.level);
  if (collection === 'brands' && q.country) result = result.filter((b) => b.country === q.country);
  if (collection === 'mechanics' && q.grade) result = result.filter((m) => String(m.grade) === q.grade);
  if (collection === 'services' && q.category) result = result.filter((s) => s.category === q.category);

  return result;
}

function compareText(a, b) {
  const x = String(a).toLowerCase();
  const y = String(b).toLowerCase();
  return x < y ? -1 : x > y ? 1 : 0;
}

const compareNum = (a, b) => a - b;
const brandName = (id) => find('brands', id)?.name ?? '';

/** Поля сортировки каждого ресурса; некоторые из них вычисляемые. */
const SORTERS = {
  cars: {
    plate: (a, b) => compareText(a.plate, b.plate),
    brand: (a, b) => compareText(`${brandName(a.brandId)} ${a.model}`, `${brandName(b.brandId)} ${b.model}`),
    year: (a, b) => compareNum(a.year, b.year),
    mileage: (a, b) => compareNum(a.mileage, b.mileage),
  },
  clients: {
    name: (a, b) => compareText(fullName(a), fullName(b)),
    registeredAt: (a, b) => compareText(a.registeredAt, b.registeredAt),
    discount: (a, b) => compareNum(a.discount, b.discount),
  },
  brands: {
    name: (a, b) => compareText(a.name, b.name),
    country: (a, b) => compareText(a.country, b.country),
    models: (a, b) => compareNum(a.models.length, b.models.length),
  },
  mechanics: {
    name: (a, b) => compareText(fullName(a), fullName(b)),
    grade: (a, b) => compareNum(a.grade, b.grade),
    experience: (a, b) => compareNum(a.experience, b.experience),
  },
  services: {
    name: (a, b) => compareText(a.name, b.name),
    price: (a, b) => compareNum(a.price, b.price),
    duration: (a, b) => compareNum(a.duration, b.duration),
  },
};

function applySort(collection, rows, sort) {
  const [field, dirRaw] = String(sort || '').split(',');
  const compare = SORTERS[collection][field];
  const dir = (dirRaw || 'asc').toLowerCase() === 'desc' ? -1 : 1;
  return [...rows].sort((a, b) => {
    const result = compare ? compare(a, b) : 0;
    // При равенстве порядок задаёт id, иначе строки «прыгали» бы между страницами.
    return (result !== 0 ? result : a.id - b.id) * dir;
  });
}

function paginate(rows, q) {
  const page = Math.max(1, Number(q.page) || 1);
  const size = Math.min(100, Math.max(1, Number(q.size) || 10));
  const total = rows.length;
  const totalPages = Math.max(1, Math.ceil(total / size));
  return {
    items: rows.slice((page - 1) * size, page * size),
    page,
    size,
    total,
    totalPages,
  };
}

// ─────────────────────────────── валидация ───────────────────────────────

const PERSON_NAME = /^[A-Za-zА-Яа-яЁё][A-Za-zА-Яа-яЁё' -]*$/;
const EMAIL = /^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[A-Za-z]{2,}$/;
const PLATE = /^[АВЕКМНОРСТУХ]\d{3}[АВЕКМНОРСТУХ]{2}\d{2,3}$/;
const FUELS = ['petrol', 'diesel', 'hybrid', 'electric', 'gas'];
const LEVELS = ['standard', 'silver', 'gold'];
const CATEGORIES = ['maintenance', 'engine', 'chassis', 'electrics', 'body', 'tires'];

const str = (v) => (typeof v === 'string' ? v.trim() : '');
const inRange = (v, min, max) =>
  v !== null && v !== '' && Number.isInteger(Number(v)) && Number(v) >= min && Number(v) <= max;
const ids = (v) =>
  Array.isArray(v) ? [...new Set(v.map(Number).filter((n) => Number.isInteger(n)))] : [];

function validatePerson(e, body) {
  if (!str(body.lastName)) e.lastName = 'Укажите фамилию';
  else if (!PERSON_NAME.test(str(body.lastName))) e.lastName = 'Только буквы, пробел и дефис';
  if (!str(body.firstName)) e.firstName = 'Укажите имя';
  else if (!PERSON_NAME.test(str(body.firstName))) e.firstName = 'Только буквы, пробел и дефис';
  const phone = digitsOnly(body.phone);
  if (phone.length !== 11 || !/^[78]/.test(phone)) e.phone = 'Номер вида +7 (916) 123-45-67';
}

/** Ключи объекта ошибок совпадают с именами полей формы. */
function validate(collection, body, id = null) {
  const e = {};

  if (collection === 'cars') {
    const plate = normalizePlate(body.plate);
    if (!plate) e.plate = 'Укажите госномер';
    else if (!PLATE.test(plate)) e.plate = 'Формат А123ВС77';
    else {
      const dup = db.cars.find((c) => normalizePlate(c.plate) === plate && c.id !== id);
      if (dup) e.plate = `Госномер уже зарегистрирован (автомобиль №${dup.id})`;
    }

    const vin = str(body.vin).toUpperCase();
    if (vin.length !== 17 || /[IOQ]/.test(vin) || !/^[A-Z0-9]+$/.test(vin)) {
      e.vin = 'VIN — 17 знаков, латиница и цифры без I, O, Q';
    } else {
      const dup = db.cars.find((c) => c.vin.toUpperCase() === vin && c.id !== id);
      if (dup) e.vin = `VIN уже зарегистрирован (автомобиль №${dup.id})`;
    }

    const brand = find('brands', body.brandId);
    if (!brand) e.brandId = 'Марка не найдена';
    else if (!brand.models.includes(str(body.model))) e.model = 'Такой модели нет у марки';

    if (!inRange(body.year, 1950, new Date().getFullYear() + 1)) e.year = 'Некорректный год выпуска';
    if (!inRange(body.mileage, 0, 2000000)) e.mileage = 'Пробег от 0 до 2 000 000 км';
    if (!FUELS.includes(body.fuel)) e.fuel = 'Неизвестный тип двигателя';
    if (!find('clients', body.clientId)) e.clientId = 'Клиент не найден';

    const mechanicIds = ids(body.mechanicIds);
    if (mechanicIds.length < 1 || mechanicIds.length > 3) e.mechanicIds = 'От одного до трёх мастеров';
    else if (mechanicIds.some((x) => !find('mechanics', x))) e.mechanicIds = 'Мастер не найден';

    const serviceIds = ids(body.serviceIds);
    if (serviceIds.length < 1) e.serviceIds = 'Выберите хотя бы одну услугу';
    else if (serviceIds.some((x) => !find('services', x))) e.serviceIds = 'Услуга не найдена';
  }

  if (collection === 'clients') {
    validatePerson(e, body);
    if (!e.phone) {
      const dup = db.clients.find((c) => digitsOnly(c.phone) === digitsOnly(body.phone) && c.id !== id);
      if (dup) e.phone = `Телефон уже есть у клиента ${shortName(dup)}`;
    }
    const email = str(body.email).toLowerCase();
    if (!EMAIL.test(email)) e.email = 'Адрес вида name@example.ru';
    else {
      const dup = db.clients.find((c) => c.email.toLowerCase() === email && c.id !== id);
      if (dup) e.email = `Эта почта уже указана у клиента ${shortName(dup)}`;
    }
    if (!inRange(body.discount, 0, 30)) e.discount = 'От 0 до 30 %';

    const card = body.card && typeof body.card === 'object' ? body.card : {};
    if (!/^AS-\d{6}$/.test(str(card.number).toUpperCase())) e['card.number'] = 'Формат AS-000123';
    if (!LEVELS.includes(card.level)) e['card.level'] = 'Неизвестный уровень карты';
    if (!inRange(card.bonusPoints, 0, 100000)) e['card.bonusPoints'] = 'От 0 до 100 000';
  }

  if (collection === 'brands') {
    if (str(body.name).length < 2) e.name = 'Укажите название марки';
    if (str(body.country).length < 2) e.country = 'Укажите страну';
    const models = Array.isArray(body.models) ? body.models.map(str).filter(Boolean) : [];
    if (!models.length) e.models = 'Укажите хотя бы одну модель';
  }

  if (collection === 'mechanics') {
    validatePerson(e, body);
    if (!inRange(body.grade, 1, 6)) e.grade = 'Разряд от 1 до 6';
    if (!inRange(body.experience, 0, 60)) e.experience = 'Стаж от 0 до 60 лет';
    if (!inRange(body.capacity, 1, 10)) e.capacity = 'От 1 до 10 автомобилей';
    else if (id !== null && Number(body.capacity) < mechanicLoad(id)) {
      const load = mechanicLoad(id);
      e.capacity = `Мастер уже ведёт ${load} ${plural(load, 'автомобиль', 'автомобиля', 'автомобилей')}`;
    }
  }

  if (collection === 'services') {
    if (str(body.name).length < 3) e.name = 'Название не короче 3 символов';
    if (!CATEGORIES.includes(body.category)) e.category = 'Неизвестная категория';
    if (!inRange(body.price, 1, 500000)) e.price = 'Цена от 1 до 500 000 ₽';
    if (!inRange(body.duration, 5, 1440) || Number(body.duration) % 5 !== 0) {
      e.duration = 'От 5 до 1440 минут, кратно 5';
    }
  }

  return e;
}

function normalize(collection, body) {
  const num = (v) => (v == null || v === '' ? null : Number(v));
  switch (collection) {
    case 'cars':
      return {
        plate: normalizePlate(body.plate),
        vin: str(body.vin).toUpperCase(),
        brandId: num(body.brandId),
        model: str(body.model),
        year: num(body.year),
        mileage: num(body.mileage),
        fuel: body.fuel,
        clientId: num(body.clientId),
        mechanicIds: ids(body.mechanicIds),
        serviceIds: ids(body.serviceIds),
      };
    case 'clients':
      return {
        lastName: str(body.lastName),
        firstName: str(body.firstName),
        middleName: str(body.middleName),
        phone: str(body.phone),
        email: str(body.email).toLowerCase(),
        discount: num(body.discount),
        registeredAt: str(body.registeredAt),
        card: {
          number: str(body.card.number).toUpperCase(),
          level: body.card.level,
          issuedAt: str(body.card.issuedAt),
          expiresAt: str(body.card.expiresAt),
          bonusPoints: num(body.card.bonusPoints),
        },
      };
    case 'brands':
      return { name: str(body.name), country: str(body.country), models: body.models.map(str).filter(Boolean) };
    case 'mechanics':
      return {
        lastName: str(body.lastName),
        firstName: str(body.firstName),
        middleName: str(body.middleName),
        phone: str(body.phone),
        grade: num(body.grade),
        experience: num(body.experience),
        capacity: num(body.capacity),
        hiredAt: str(body.hiredAt),
      };
    case 'services':
      return { name: str(body.name), category: body.category, price: num(body.price), duration: num(body.duration) };
    default:
      return { ...body };
  }
}

// ─────────────────────── ограничения целостности (409) ───────────────────────

/**
 * Запись к мастеру: у мастера ограниченное число мест (capacity) — как
 * число экземпляров у книги. Если все места заняты, закрепить за ним
 * ещё один автомобиль нельзя. Возвращает текст конфликта или null.
 */
function mechanicConflict(car, carId) {
  const before = carId === null ? [] : find('cars', carId).mechanicIds;
  for (const mechanicId of car.mechanicIds) {
    if (before.includes(mechanicId)) continue; // мастер был закреплён и раньше
    const m = find('mechanics', mechanicId);
    const load = mechanicLoad(mechanicId, carId);
    if (load >= m.capacity) {
      return (
        `У мастера ${shortName(m)} нет свободных мест: ведёт ${load} ` +
        `${plural(load, 'автомобиль', 'автомобиля', 'автомобилей')} из ${m.capacity}`
      );
    }
  }
  return null;
}

/** Можно ли удалить запись; hard — физическое удаление. Текст конфликта или null. */
function deleteConflict(collection, row, hard) {
  if (collection === 'brands') {
    // Для логического удаления считаются только действующие автомобили.
    const cars = db.cars.filter((c) => c.brandId === row.id && (hard || !c.deletedAt)).length;
    if (cars > 0) {
      return (
        `Нельзя удалить марку «${row.name}»: на неё ` +
        `${plural(cars, 'ссылается', 'ссылаются', 'ссылаются')} ${cars} ` +
        `${plural(cars, 'автомобиль', 'автомобиля', 'автомобилей')}` +
        `${hard ? ' (с учётом удалённых)' : ''}. Сначала смените у них марку или удалите их.`
      );
    }
  }
  if (collection === 'clients' && hard) {
    const cars = db.cars.filter((c) => c.clientId === row.id).length;
    if (cars > 0) {
      return `Нельзя удалить навсегда: за клиентом числится ${cars} ${plural(cars, 'автомобиль', 'автомобиля', 'автомобилей')}`;
    }
  }
  return null;
}

/** Мастер или услуга стёрты навсегда — ссылки на них убираются из автомобилей. */
function afterHardDelete(collection, id) {
  const key = { mechanics: 'mechanicIds', services: 'serviceIds' }[collection];
  if (!key) return;
  for (const car of db.cars) car[key] = car[key].filter((x) => x !== id);
}

// ─────────────────────── проверка прав (настоящая) ───────────────────────
// Эти правила выполняются на сервере до любого обращения к данным.
// Клиентские проверки повторяют их только для того, чтобы не показывать
// кнопки, которые всё равно не сработают.

const roleAtLeast = (user, role) => !!user && ROLES[user.role] >= ROLES[role];

/** Причина отказа (код 403) либо null, если операция разрешена. */
function forbidReason(user, { method, collection, id, action, q }) {
  if (action === 'extend-card') {
    // Продлить клубную карту может только её владелец — клиент.
    return user.role === 'client' && collection === 'clients' && id === user.clientId
      ? null
      : 'Продлить клубную карту может только её владелец';
  }
  if (action === 'restore') {
    return roleAtLeast(user, 'admin')
      ? null
      : 'Восстанавливать удалённые записи может только администратор';
  }
  if (method === 'DELETE' && q.hard === 'true') {
    return roleAtLeast(user, 'admin')
      ? null
      : 'Удалять записи навсегда может только администратор';
  }

  if (method === 'GET') {
    // Каталог услуг и марок открыт всем, кто вошёл.
    if (collection === 'services' || collection === 'brands') return null;
    if (roleAtLeast(user, 'mechanic')) return null;

    // Свою карточку клиента (с клубной картой) клиент видит.
    if (collection === 'clients' && user.role === 'client' && id !== null && id === user.clientId) {
      return null;
    }

    if (collection === 'cars' && user.role === 'client') {
      if (id === null) {
        return String(q.clientId || '') === String(user.clientId)
          ? null
          : 'Клиенту доступны только его собственные автомобили';
      }
      const car = find('cars', id);
      return car && car.clientId === user.clientId
        ? null
        : 'Клиенту доступны только его собственные автомобили';
    }
    return 'Недостаточно прав для просмотра этого раздела';
  }

  // Создание, изменение, удаление записей.
  return roleAtLeast(user, 'mechanic')
    ? null
    : 'Изменять данные может только мастер или администратор';
}

// ──────────────────────────── HTTP-обвязка ────────────────────────────

function cors(res) {
  res.setHeader('Access-Control-Allow-Origin', ORIGIN);
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Max-Age', '86400');
  res.setHeader('Vary', 'Origin');
}

function send(res, status, payload) {
  cors(res);
  if (payload === undefined || status === 204) {
    res.writeHead(204);
    res.end();
    return;
  }
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

function fail(res, status, message) {
  send(res, status, { message });
}

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  if (!chunks.length) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    return null; // признак некорректного JSON
  }
}

// ─────────────────────────────── маршруты ───────────────────────────────

async function handle(req, res, url) {
  const q = Object.fromEntries(url.searchParams.entries());
  const path = url.pathname.replace(/\/+$/, '') || '/';
  const method = req.method.toUpperCase();

  // Учебные переключатели поведения
  if (q.__fail) {
    return fail(res, Number(q.__fail), 'Ошибка вызвана намеренно параметром __fail');
  }

  // ── служебные ──
  if (path === '/api/__reset' && method === 'POST') {
    seed();
    return send(res, 200, { message: 'Данные восстановлены в исходное состояние' });
  }

  if (path === '/api/__health' && method === 'GET') {
    return send(res, 200, { status: 'ok', time: new Date().toISOString() });
  }

  // ── аутентификация ──
  // Эти адреса открыты: без них невозможно получить токен.

  if (path === '/api/auth/register' && method === 'POST') {
    const body = await readBody(req);
    if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

    const errors = {};
    const username = str(body.username).toLowerCase();
    if (!username) errors.username = 'Укажите логин';
    else if (!/^[a-z0-9_]{3,20}$/.test(username)) {
      errors.username = 'Латинские буквы, цифры и подчёркивание, от 3 до 20 знаков';
    } else if (db.users.some((u) => u.username === username)) {
      errors.username = 'Такой логин уже занят';
    }
    const passwordError = validatePassword(body.password);
    if (passwordError) errors.password = passwordError;
    if (!str(body.lastName)) errors.lastName = 'Укажите фамилию';
    if (!str(body.firstName)) errors.firstName = 'Укажите имя';
    if (Object.keys(errors).length) return send(res, 422, { message: 'Ошибка валидации', errors });

    // Роль нового пользователя всегда «клиент»: выдать себе права
    // при регистрации нельзя, роль меняет только администратор.
    db.seq.users += 1;
    const user = {
      id: db.seq.users,
      username,
      password: hashPassword(body.password),
      role: 'client',
      lastName: str(body.lastName),
      firstName: str(body.firstName),
      clientId: null,
      mechanicId: null,
    };
    db.users.push(user);
    return send(res, 201, session(user));
  }

  if (path === '/api/auth/login' && method === 'POST') {
    const body = await readBody(req);
    if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');
    const user = db.users.find((u) => u.username === str(body.username).toLowerCase());
    // Один и тот же текст для неизвестного логина и неверного пароля:
    // иначе по ответу можно перебором узнать существующие логины.
    if (!user || !verifyPassword(body.password, user.password)) {
      return fail(res, 401, 'Неверный логин или пароль');
    }
    return send(res, 200, session(user));
  }

  if (path === '/api/auth/refresh' && method === 'POST') {
    const body = await readBody(req);
    const payload = readToken(body && body.refreshToken, 'refresh');
    if (!payload) return fail(res, 401, 'Токен обновления недействителен');
    const user = db.users.find((u) => u.id === payload.sub);
    if (!user) return fail(res, 401, 'Пользователь удалён');
    return send(res, 200, session(user));
  }

  if (path === '/api/auth/me' && method === 'GET') {
    const me = currentUser(req);
    if (!me) return fail(res, 401, 'Требуется вход в систему');
    return send(res, 200, publicUser(me));
  }

  if (path === '/api/auth/logout' && method === 'POST') {
    // Токены хранятся только у клиента, серверного состояния сессии нет:
    // выход сводится к удалению токенов в браузере.
    return send(res, 204);
  }

  // ── дальше всё требует входа ──
  const user = currentUser(req);
  if (!user) return fail(res, 401, 'Требуется вход в систему');

  // ── пользователи и роли: только администратор ──
  const userRoute = path.match(/^\/api\/users(?:\/(\d+))?$/);
  if (userRoute) {
    if (!roleAtLeast(user, 'admin')) {
      return fail(res, 403, 'Управление пользователями доступно только администратору');
    }
    const id = userRoute[1] ? Number(userRoute[1]) : null;

    if (id === null && method === 'GET') {
      const rows = db.users.map(publicUser);
      return send(res, 200, {
        items: rows, page: 1, size: rows.length, total: rows.length, totalPages: 1,
      });
    }
    if (id !== null && (method === 'PATCH' || method === 'PUT')) {
      const row = db.users.find((u) => u.id === id);
      if (!row) return fail(res, 404, 'Пользователь не найден');
      const body = await readBody(req);
      const role = str(body && body.role);
      if (!ROLES[role]) {
        return send(res, 422, { message: 'Ошибка валидации', errors: { role: 'Неизвестная роль' } });
      }
      if (row.id === user.id && role !== 'admin') {
        return fail(res, 409, 'Нельзя снять права администратора с самого себя');
      }
      row.role = role;
      return send(res, 200, publicUser(row));
    }
    if (id !== null && method === 'DELETE') {
      const index = db.users.findIndex((u) => u.id === id);
      if (index === -1) return fail(res, 404, 'Пользователь не найден');
      if (id === user.id) return fail(res, 409, 'Нельзя удалить собственную учётную запись');
      db.users.splice(index, 1);
      return send(res, 204);
    }
    return fail(res, 404, 'Адрес ' + method + ' ' + path + ' не обслуживается');
  }

  // ── статистика: только администратор ──
  if (path === '/api/stats' && method === 'GET') {
    if (!roleAtLeast(user, 'admin')) {
      return fail(res, 403, 'Статистика доступна только администратору');
    }
    const live = (c) => db[c].filter((x) => !x.deletedAt).length;
    const removed = (c) => db[c].filter((x) => x.deletedAt).length;
    return send(res, 200, {
      counts: Object.fromEntries(COLLECTIONS.map((c) => [c, live(c)])),
      deleted: Object.fromEntries(COLLECTIONS.map((c) => [c, removed(c)])),
      users: Object.fromEntries(
        Object.keys(ROLES).map((r) => [r, db.users.filter((u) => u.role === r).length]),
      ),
      servicePrice: db.cars
        .filter((c) => !c.deletedAt)
        .flatMap((c) => c.serviceIds)
        .reduce((sum, id) => sum + ((find('services', id) || {}).price || 0), 0),
    });
  }

  // ── единообразный CRUD ──
  const bulk = path.match(/^\/api\/([a-z]+)\/bulk-delete$/);
  if (bulk && method === 'POST') {
    const collection = bulk[1];
    if (!COLLECTIONS.includes(collection)) return fail(res, 404, 'Ресурс не найден');

    const denied = forbidReason(user, { method, collection, id: null, action: null, q });
    if (denied) return fail(res, 403, denied);

    const body = await readBody(req);
    const list = ids(body && body.ids);
    if (!list.length) {
      return send(res, 422, { message: 'Ошибка валидации', errors: { ids: 'Передайте непустой список идентификаторов' } });
    }

    // Сначала проверяются все записи: если хотя бы одну удалить нельзя,
    // не удаляется ни одна — как в транзакции.
    const rows = db[collection].filter((x) => list.includes(x.id) && !x.deletedAt);
    for (const row of rows) {
      const conflict = deleteConflict(collection, row, false);
      if (conflict) return fail(res, 409, conflict);
    }
    const now = new Date().toISOString();
    for (const row of rows) row.deletedAt = now;
    return send(res, 200, { deleted: rows.length });
  }

  const m = path.match(/^\/api\/([a-z]+)(?:\/(\d+))?(?:\/(restore|extend-card))?$/);
  if (m) {
    const collection = m[1];
    const id = m[2] ? Number(m[2]) : null;
    const action = m[3] || null;

    if (!COLLECTIONS.includes(collection)) return fail(res, 404, 'Ресурс не найден');

    // Права проверяются один раз для всех операций ресурса — до того,
    // как запрос доберётся до данных.
    const denied = forbidReason(user, { method, collection, id, action, q });
    if (denied) return fail(res, 403, denied);

    const expand = EXPANDERS[collection];

    // восстановление
    // продление клубной карты на год: от сегодняшнего дня,
    // если срок уже истёк, иначе от даты окончания
    if (action === 'extend-card' && method === 'POST') {
      const row = db.clients.find((x) => x.id === id && !x.deletedAt);
      if (!row) return fail(res, 404, 'Объект не найден');
      const today = new Date().toISOString().slice(0, 10);
      const from = new Date(row.card.expiresAt > today ? row.card.expiresAt : today);
      from.setFullYear(from.getFullYear() + 1);
      row.card.expiresAt = from.toISOString().slice(0, 10);
      return send(res, 200, expand(row));
    }

    if (action === 'restore' && method === 'POST') {
      const row = find(collection, id);
      if (!row) return fail(res, 404, 'Объект не найден');
      row.deletedAt = null;
      return send(res, 200, expand(row));
    }

    // список
    if (id === null && method === 'GET') {
      let rows = db[collection];
      if (q.includeDeleted !== 'true') rows = rows.filter((x) => !x.deletedAt);
      rows = applyFilters(collection, rows, q);
      rows = applySort(collection, rows, q.sort);
      const page = paginate(rows, q);
      return send(res, 200, { ...page, items: page.items.map(expand) });
    }

    // одна запись
    if (id !== null && method === 'GET') {
      const row = db[collection].find((x) => x.id === id && (q.includeDeleted === 'true' || !x.deletedAt));
      if (!row) return fail(res, 404, 'Объект не найден');
      return send(res, 200, expand(row));
    }

    // создание
    if (id === null && method === 'POST') {
      const body = await readBody(req);
      if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

      const errors = validate(collection, body);
      if (Object.keys(errors).length) return send(res, 422, { message: 'Ошибка валидации', errors });

      const data = normalize(collection, body);
      if (collection === 'cars') {
        const conflict = mechanicConflict(data, null);
        if (conflict) return fail(res, 409, conflict);
      }
      return send(res, 201, expand(push(collection, data)));
    }

    // изменение
    if (id !== null && (method === 'PUT' || method === 'PATCH')) {
      const row = db[collection].find((x) => x.id === id && !x.deletedAt);
      if (!row) return fail(res, 404, 'Объект не найден');

      const body = await readBody(req);
      if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

      const merged = method === 'PATCH' ? { ...row, ...body } : body;
      const errors = validate(collection, merged, id);
      if (Object.keys(errors).length) return send(res, 422, { message: 'Ошибка валидации', errors });

      const data = normalize(collection, merged);
      if (collection === 'cars') {
        const conflict = mechanicConflict(data, id);
        if (conflict) return fail(res, 409, conflict);
      }
      Object.assign(row, data);
      return send(res, 200, expand(row));
    }

    // удаление
    if (id !== null && method === 'DELETE') {
      const hard = q.hard === 'true';
      const index = db[collection].findIndex((x) => x.id === id);
      if (index === -1) return fail(res, 404, 'Объект не найден');

      const conflict = deleteConflict(collection, db[collection][index], hard);
      if (conflict) return fail(res, 409, conflict);

      if (hard) {
        db[collection].splice(index, 1);
        afterHardDelete(collection, id);
      } else {
        db[collection][index].deletedAt = new Date().toISOString();
      }
      return send(res, 204);
    }
  }

  return fail(res, 404, `Адрес ${method} ${path} не обслуживается`);
}

// ─────────────────────────────── запуск ───────────────────────────────

seed();

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

  // Предварительный запрос браузера. Без этого обработчика
  // на web не заработают запросы PUT, DELETE и запросы с JSON-телом.
  if (req.method === 'OPTIONS') {
    cors(res);
    res.writeHead(204);
    return res.end();
  }

  const delay = Number(url.searchParams.get('__delay') || 0);
  if (delay > 0) await new Promise((r) => setTimeout(r, Math.min(delay, 10000)));

  const started = Date.now();
  try {
    await handle(req, res, url);
  } catch (err) {
    console.error(err);
    if (!res.headersSent) fail(res, 500, 'Внутренняя ошибка сервера: ' + err.message);
  }
  console.log(
    `${req.method.padEnd(6)} ${url.pathname}${url.search}  → ${res.statusCode}  ${Date.now() - started} мс`
  );
});

server.listen(PORT, () => {
  console.log('');
  console.log('  Учебное API «Автосервис»');
  console.log(`  Адрес:                http://localhost:${PORT}/api`);
  console.log(`  Разрешённый источник: ${ORIGIN}`);
  console.log('');
  console.log(`  Срок жизни токена:    ${ACCESS_TTL} с (--ttl)`);
  console.log('');
  console.log('  Учётные записи:  admin / Admin#2026     — администратор');
  console.log('                   master / Master#2026   — мастер');
  console.log('                   client / Client#2026   — клиент');
  console.log('');
  console.log('  Сброс данных:    POST /api/__reset');
  console.log('  Задержка ответа: любой запрос с ?__delay=1500');
  console.log('  Ошибка по требованию: любой запрос с ?__fail=500');
  console.log('');
});
