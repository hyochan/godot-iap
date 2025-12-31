import React from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';

type Sponsor = {
  name: string;
  url: string;
  logo: string;
  width?: number;
  description?: string;
};

type SponsorSectionProps = {
  variant?: 'full' | 'compact';
  showLabel?: boolean;
};

const sponsors: Sponsor[] = [
  {
    name: 'Meta',
    url: 'https://meta.com',
    logo: 'https://www.openiap.dev/meta.svg',
    width: 320,
    description: 'Meta',
  },
];

const SponsorSection: React.FC<SponsorSectionProps> = ({
  variant = 'full',
  showLabel,
}) => {
  const showLabelResolved = showLabel ?? variant === 'full';
  const isFull = variant === 'full';

  return (
    <section className={styles.container} data-variant={variant}>
      {isFull ? (
        <header className={styles.header}>
          <h2>Our Sponsors</h2>
          <p>
            We're building the OpenIAP ecosystem—spec, type system, and native
            SDKs—so developers across Expo, React Native, Flutter, Godot, and Kotlin
            Multiplatform can ship in-app purchases without headaches. If you or
            your company rely on these tools, please consider supporting ongoing
            work via{' '}
            <a
              href="https://www.openiap.dev/sponsors"
              target="_blank"
              rel="noreferrer"
            >
              openiap.dev/sponsors
            </a>
            . Sponsors receive shout-outs in each release, tailored support by
            tier, and early coordination on new integrations.
          </p>
        </header>
      ) : null}

      <div className={styles.grid}>
        {sponsors.map((sponsor) => (
          <a
            key={sponsor.name}
            href={sponsor.url}
            target="_blank"
            rel="noreferrer"
            className={styles.card}
          >
            <img
              src={sponsor.logo}
              alt={sponsor.name}
              style={{
                width: variant === 'compact' ? 120 : sponsor.width ?? 280,
              }}
            />
            {showLabelResolved && sponsor.description ? (
              <span
                className={clsx(
                  styles.description,
                  variant === 'compact' ? styles.descriptionCompact : undefined,
                )}
              >
                {sponsor.description}
              </span>
            ) : null}
          </a>
        ))}
      </div>

      {isFull ? (
        <p className={styles.disclaimer}>
          Have insights on requirements or want to discuss
          partnerships? Join the conversation at{' '}
          <a
            href="https://github.com/hyochan/godot-iap/discussions"
            target="_blank"
            rel="noreferrer"
          >
            github.com/hyochan/godot-iap/discussions
          </a>
          .
        </p>
      ) : null}
    </section>
  );
};

export default SponsorSection;
