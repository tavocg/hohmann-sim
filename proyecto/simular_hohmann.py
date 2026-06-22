from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from scipy.integrate import solve_ivp


MU = 3.9845571e5  # km^3 s^-2, Tierra; equivale a 3.9845571e14 m^3 s^-2.
R_EARTH = 6378.137  # km
R1 = R_EARTH + 300.0
R2 = 42159.036216630644
# Criterios de aceptacion: la orbita final debe parecerse a una circular GEO,
# no solo pasar momentaneamente por el radio objetivo.
SUCCESS_A_REL = 0.02
SUCCESS_EPSILON = 0.02


@dataclass(frozen=True)
class Hohmann:
    dv1: float
    dv2: float
    tof: float
    at: float


# solve_ivp exige una funcion f(t, y); el sistema es autonomo, por eso _t no se usa.
def aceleracion_gravitatoria(_t: float, y: np.ndarray, mu: float = MU) -> np.ndarray:
    r = y[:2]
    v = y[2:]
    rn = np.linalg.norm(r)
    a = -mu * r / rn**3
    return np.array([v[0], v[1], a[0], a[1]])


def energia(y: np.ndarray, mu: float = MU) -> float:
    r = np.linalg.norm(y[:2])
    v2 = float(np.dot(y[2:], y[2:]))
    return 0.5 * v2 - mu / r


def momento_angular(y: np.ndarray) -> float:
    return float(y[0] * y[3] - y[1] * y[2])


def calcular_hohmann(r1: float = R1, r2: float = R2, mu: float = MU) -> Hohmann:
    # La elipse de Hohmann es tangente a las dos orbitas circulares.
    at = 0.5 * (r1 + r2)
    vc1 = np.sqrt(mu / r1)
    vc2 = np.sqrt(mu / r2)
    # Estas velocidades salen del desarrollo energetico explicado en la metodologia.
    vt1 = np.sqrt(mu * (2.0 / r1 - 1.0 / at))
    vt2 = np.sqrt(mu * (2.0 / r2 - 1.0 / at))
    tof = np.pi * np.sqrt(at**3 / mu)
    return Hohmann(dv1=vt1 - vc1, dv2=vc2 - vt2, tof=tof, at=at)


def integrar_orbita(y0: np.ndarray, tf: float, n: int = 700) -> tuple[np.ndarray, np.ndarray]:
    t_eval = np.linspace(0.0, tf, n)
    # DOP853 se usa por su precision alta en problemas orbitales suaves.
    sol = solve_ivp(
        aceleracion_gravitatoria,
        (0.0, tf),
        y0,
        t_eval=t_eval,
        rtol=1e-10,
        atol=1e-12,
        method="DOP853",
    )
    if not sol.success:
        raise RuntimeError(sol.message)
    return sol.t, sol.y.T


def aplicar_impulso(
    y: np.ndarray, dv_tangencial: float, error_mag: float = 0.0, error_ang: float = 0.0
) -> np.ndarray:
    r = y[:2]
    # Para una orbita antihoraria, la direccion tangencial local es (-y, x).
    tangente = np.array([-r[1], r[0]]) / np.linalg.norm(r)
    c, s = np.cos(error_ang), np.sin(error_ang)
    # El error angular rota el impulso; el error de magnitud cambia su modulo.
    direccion = np.array([c * tangente[0] - s * tangente[1], s * tangente[0] + c * tangente[1]])
    out = y.copy()
    out[2:] += (dv_tangencial + error_mag) * direccion
    return out


def elementos_orbitales(y: np.ndarray, mu: float = MU) -> tuple[float, float]:
    energia_especifica = energia(y, mu)
    h = momento_angular(y)
    a = -mu / (2.0 * energia_especifica)
    # max evita una excentricidad imaginaria por redondeo cuando epsilon debe ser 0.
    e2 = max(0.0, 1.0 + 2.0 * energia_especifica * h**2 / mu**2)
    return a, np.sqrt(e2)


def simular_transferencia(
    sigma_mag_rel: float = 0.0,
    sigma_ang_deg: float = 0.0,
    rng: np.random.Generator | None = None,
    trayectoria: bool = False,
) -> dict[str, np.ndarray | float | bool]:
    rng = np.random.default_rng(1234) if rng is None else rng
    h = calcular_hohmann()
    y0 = np.array([R1, 0.0, 0.0, np.sqrt(MU / R1)])
    # Primer impulso: inyecta la nave en la elipse de transferencia.
    error_mag1 = rng.normal(0.0, sigma_mag_rel * h.dv1)
    error_ang1 = rng.normal(0.0, np.deg2rad(sigma_ang_deg))
    y1 = aplicar_impulso(y0, h.dv1, error_mag1, error_ang1)
    _, ys = integrar_orbita(y1, h.tof, n=900 if trayectoria else 2)
    yf = ys[-1]
    # Segundo impulso: intenta circularizar en el apoapsis de la transferencia.
    error_mag2 = rng.normal(0.0, sigma_mag_rel * h.dv2)
    error_ang2 = rng.normal(0.0, np.deg2rad(sigma_ang_deg))
    y2 = aplicar_impulso(yf, h.dv2, error_mag2, error_ang2)
    a, epsilon = elementos_orbitales(y2)
    exito = abs(a - R2) / R2 < SUCCESS_A_REL and epsilon < SUCCESS_EPSILON
    return {"estado": y2, "a": a, "epsilon": epsilon, "exito": exito, "trayectoria": ys}


def simular_monte_carlo(
    sigma_mag_rel: float, sigma_ang_deg: float, n: int = 1000, seed: int = 2026
) -> dict[str, np.ndarray | float]:
    rng = np.random.default_rng(seed)
    semiejes = np.empty(n)
    excentricidades = np.empty(n)
    exitos = np.empty(n, dtype=bool)
    for i in range(n):
        # Cada iteracion representa una ejecucion posible de los dos impulsos.
        res = simular_transferencia(sigma_mag_rel, sigma_ang_deg, rng)
        semiejes[i] = float(res["a"])
        excentricidades[i] = float(res["epsilon"])
        exitos[i] = bool(res["exito"])
    return {
        "a": semiejes,
        "epsilon": excentricidades,
        "exito": exitos,
        "probabilidad": float(np.mean(exitos)),
    }


def validar_orbita_circular() -> tuple[float, float]:
    y0 = np.array([R1, 0.0, 0.0, np.sqrt(MU / R1)])
    periodo = 2.0 * np.pi * np.sqrt(R1**3 / MU)
    _, ys = integrar_orbita(y0, periodo, n=1200)
    # En una orbita circular sin impulsos, radio, energia y momento deben conservarse.
    radios = np.linalg.norm(ys[:, :2], axis=1)
    energias = np.array([energia(y) for y in ys])
    momentos = np.array([momento_angular(y) for y in ys])
    err_radio = np.max(np.abs(radios - R1)) / R1
    err_inv = max(
        np.ptp(energias) / abs(energias[0]),
        np.ptp(momentos) / abs(momentos[0]),
    )
    return float(err_radio), float(err_inv)


def main() -> None:
    out = Path(__file__).resolve().parent / "figures"
    out.mkdir(exist_ok=True)
    h = calcular_hohmann()
    ideal = simular_transferencia(trayectoria=True)
    pert = simular_transferencia(0.002, 0.20, np.random.default_rng(55), trayectoria=True)

    fig, ax = plt.subplots(figsize=(5.2, 4.2))
    theta = np.linspace(0, 2 * np.pi, 400)
    ax.plot(R1 * np.cos(theta), R1 * np.sin(theta), "--", lw=1, label="orbita inicial")
    ax.plot(R2 * np.cos(theta), R2 * np.sin(theta), "--", lw=1, label="orbita objetivo")
    for label, res in [("ideal", ideal), ("perturbada", pert)]:
        tr = np.asarray(res["trayectoria"])
        ax.plot(tr[:, 0], tr[:, 1], lw=1.6, label=label)
    ax.set_aspect("equal", adjustable="box")
    ax.set_xlabel("x (km)")
    ax.set_ylabel("y (km)")
    ax.legend(fontsize=8)
    fig.tight_layout()
    fig.savefig(out / "orbitas.pdf")
    plt.close(fig)

    niveles = np.array([0.0, 0.0005, 0.001, 0.002, 0.003, 0.005])
    probs = []
    datos_hist = None
    for s in niveles:
        datos = simular_monte_carlo(s, sigma_ang_deg=100.0 * s, n=1200)
        probs.append(datos["probabilidad"])
        if np.isclose(s, 0.002):
            datos_hist = datos

    fig, ax = plt.subplots(figsize=(5.2, 3.4))
    ax.plot(100 * niveles, probs, marker="o")
    ax.set_xlabel("desviacion estandar de magnitud (%)")
    ax.set_ylabel("probabilidad de exito")
    ax.set_ylim(-0.03, 1.03)
    ax.grid(alpha=0.3)
    fig.tight_layout()
    fig.savefig(out / "probabilidad.pdf")
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(5.2, 3.4))
    assert datos_hist is not None
    ax.hist((np.asarray(datos_hist["a"]) - R2) / R2 * 100.0, bins=35, alpha=0.75)
    ax.axvline(-2.0, color="k", ls="--", lw=1)
    ax.axvline(2.0, color="k", ls="--", lw=1)
    ax.set_xlabel("error relativo del semieje mayor final (%)")
    ax.set_ylabel("conteo")
    fig.tight_layout()
    fig.savefig(out / "histograma.pdf")
    plt.close(fig)

    err_radio, err_inv = validar_orbita_circular()
    print(f"dv1_km_s={h.dv1:.5f}")
    print(f"dv2_km_s={h.dv2:.5f}")
    print(f"tof_h={h.tof / 3600.0:.3f}")
    print(f"validacion_radio_rel={err_radio:.2e}")
    print(f"validacion_invariantes_rel={err_inv:.2e}")
    print("probabilidades=" + ",".join(f"{p:.3f}" for p in probs))
    print(f"hist_media_a_km={np.mean(datos_hist['a']):.1f}")
    print(f"hist_media_epsilon={np.mean(datos_hist['epsilon']):.4f}")


if __name__ == "__main__":
    main()
