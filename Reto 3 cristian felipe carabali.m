%% RETO 3 - ALGORITMO DE CONTROL Y CARGAS
% Curso: Software para ingenieria - UNAD
% Datos solares, eolicos y demanda tomados del codigo compartido del Reto 2.
% IMPORTANTE: la guia define SOC y umbrales. El Reto 2 solo entrega demanda
% TOTAL; no separa consumos de escuela, bombeo y alumbrado. Por eso los estados
% de carga se reportan segun SOC, pero no se puede recalcular demanda reducida
% por desconexion sin datos individuales de cada servicio.

clc;
clear;
close all;

%% 1. DATOS ORIGINALES DEL RETO 2
horas = 1:24;

solar = zeros(1,24);
for h = 6:18
    solar(h) = 25 * sin(pi * (h - 6) / 12);
end

eolica = [8 9 7 10 9 11 8 12 10 9 11 13 ...
    10 8 12 11 9 13 10 12 9 11 8 10];

demanda = [3 3 2 4 3 6 7 8 7 6 8 9 ...
    8 7 9 10 9 13 15 14 12 4 3 2];

generacion_total = solar + eolica;

assert(numel(solar)==24 && numel(eolica)==24 && numel(demanda)==24, ...
    'Cada vector debe tener exactamente 24 valores.');
assert(all(isfinite([solar eolica demanda])) && ...
    all([solar eolica demanda] >= 0), ...
    'Los datos deben ser finitos y no negativos.');

%% 2. PARAMETROS DE BATERIA
Capacidad_bat = 100; % kWh
SOC = 50;            % porcentaje inicial

SOC_hist = zeros(1,24);
Balance_hist = zeros(1,24);
Escuela = true(1,24);
Bombeo = true(1,24);
Alumbrado = true(1,24);
Estado = strings(1,24);

%% 3. SIMULACION HORARIA
for h = 1:24
    % Se supone que cada valor de potencia representa una hora de operacion.
    % Bajo ese supuesto, kW durante 1 h equivale numericamente a kWh.
    E_gen = generacion_total(h);
    E_dem = demanda(h);
    Balance = E_gen - E_dem;
    Balance_hist(h) = Balance;

    % Por defecto, todos los servicios empiezan activos en esta hora.
    escuela_activa = true;
    bombeo_activo = true;
    alumbrado_activo = true;

    %% 4. ACTUALIZACION DEL SOC
    if Balance >= 0
        Excedente = Balance;
        SOC = SOC + (Excedente / Capacidad_bat) * 100;
        SOC = min(SOC, 100);
        Estado(h) = "SUPERAVIT";
    else
        Faltante = abs(Balance);
        SOC = SOC - (Faltante / Capacidad_bat) * 100;
        SOC = max(SOC, 0);
        Estado(h) = "DEFICIT";

        %% 5. UMBRALES DE DESCONEXION SEGUN LA GUIA
        if SOC > 40
            % Ruta segura: todos los servicios activos.
            escuela_activa = true;
            bombeo_activo = true;
            alumbrado_activo = true;
        elseif SOC > 20
            % Ruta de alerta: suspender alumbrado publico.
            escuela_activa = true;
            bombeo_activo = true;
            alumbrado_activo = false;
        else
            % Ruta de emergencia: suspender alumbrado y bombeo.
            escuela_activa = true;
            bombeo_activo = false;
            alumbrado_activo = false;
        end
    end

    SOC_hist(h) = SOC;
    Escuela(h) = escuela_activa;
    Bombeo(h) = bombeo_activo;
    Alumbrado(h) = alumbrado_activo;

    %% 6. REPORTE DE CONSOLA
    fprintf('\\n========== HORA %02d ==========\\n', h);
    fprintf('Solar: %.2f kW | Eolica: %.2f kW | Generacion total: %.2f kW\\n', ...
        solar(h), eolica(h), generacion_total(h));
    fprintf('Demanda: %.2f kW | Balance: %.2f kW | SOC: %.2f %%\\n', ...
        demanda(h), Balance, SOC);
    fprintf('Estado energetico: %s\\n', char(Estado(h)));
    fprintf('Escuela: %s | Bombeo: %s | Alumbrado: %s\\n', ...
        estadoTexto(Escuela(h)), estadoTexto(Bombeo(h)), estadoTexto(Alumbrado(h)));

    if SOC == 0 && Balance < 0
        fprintf('ADVERTENCIA: bateria agotada; puede quedar demanda sin atender.\\n');
    end
end

%% 7. RESUMEN FINAL
fprintf('\\n===== RESUMEN DE LAS 24 HORAS =====\\n');
fprintf('SOC inicial: 50.00 %%\\n');
fprintf('SOC final: %.2f %%\\n', SOC_hist(end));
fprintf('Balance neto sumado por hora: %.2f kWh-equivalentes\\n', sum(Balance_hist));
fprintf('Horas con deficit: %d\\n', sum(Balance_hist < 0));
fprintf('Horas con superavit o balance cero: %d\\n', sum(Balance_hist >= 0));
fprintf(['NOTA: la demanda del Reto 2 es total; para calcular el efecto de cada ' ...
    'desconexion se requieren consumos individuales.\\n']);
fprintf('Simulacion finalizada.\\n');

%% 8. GRAFICA DEL SOC
figure('Name','Estado de carga de la bateria');
plot(horas, SOC_hist, '-o', 'LineWidth', 2);
hold on;
yline(40, '--', 'Alerta 40%');
yline(20, '--', 'Emergencia 20%');
yline(100, ':', 'Limite 100%');
grid on;
xlabel('Tiempo (horas)');
ylabel('Estado de carga SOC (%)');
title('Estado de carga de la bateria durante 24 horas');
xlim([1 24]);
ylim([0 105]);
hold off;

%% 9. GRAFICA GENERACION VS DEMANDA
figure('Name','Generacion hibrida y demanda');
plot(horas, generacion_total, '-o', 'LineWidth', 2, 'Color', [0 0.6 0]);
hold on;
plot(horas, demanda, '-s', 'LineWidth', 2, 'Color', [0.8 0 0]);
grid on;
xlabel('Tiempo (horas)');
ylabel('Potencia (kW)');
title('Generacion Hibrida vs Demanda de la Comunidad');
legend('Generacion Hibrida Total', 'Demanda de la Comunidad', 'Location', 'best');
hold off;

%% FUNCION LOCAL
function texto = estadoTexto(activo)
    if activo
        texto = 'ACTIVO';
    else
        texto = 'SUSPENDIDO';
    end
end
